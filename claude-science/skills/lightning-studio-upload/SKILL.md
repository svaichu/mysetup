---
name: lightning-studio-upload
description: Move a local/HPC code tree onto a Lightning AI studio so it can be used by a Lightning Job. Covers the non-obvious failure mode that Lightning's upload backend returns HTTP 501 on zero-byte files (which breaks upload_folder, upload_file, AND `lightning studio cp -r` on any Python package, since packages contain empty __init__.py markers), the tarball workaround that is immune to it, teamspace/owner resolution (user vs org), exporting LIGHTNING_API_KEY/LIGHTNING_USER_ID for child processes, using the correct uv-installed SDK interpreter, and what to exclude. Use when the user says "upload the folder to the studio", "move my code to lightning", "get my repo onto the studio for a job", or an upload_folder / studio cp is failing with 501.
---

# Lightning Studio: uploading a code tree

Get a local or HPC-resident code tree onto a **Lightning AI studio** so a
Lightning Job can run against it. This skill encodes the failure modes verified
empirically — most importantly the **zero-byte-file 501** that silently breaks
every naive upload path.

Companion skills: `lightning-ai-jobs` (submit/monitor the job once code is up),
`remote-compute-ssh` (the SSH dispatch workflow). All commands below run through
`c = host.compute.create('ssh:<host>')` in the **repl tool**, executing on the
machine that holds the code (e.g. an HPC login node).

## The one thing to know first

**Lightning's upload API returns HTTP 501 on any zero-byte file.** This is a
backend limitation, not an SDK bug — it breaks *all* of these identically:

- `Studio.upload_folder(...)`  (SDK)
- `Studio.upload_file(...)` on an empty file  (SDK)
- `lightning studio cp -r <dir> lit://...`  (CLI)

They share one upload backend. A run dies on the **first** empty file it
reaches (e.g. `README.md` at 0 bytes, or a package's `__init__.py`), after
uploading everything before it. Non-empty files always succeed — which is why
small test uploads pass and lull you into a wrong "SDK version" or "batch size"
theory. **Any Python package trips this**, because `__init__.py` markers are
routinely empty and are required for imports to work (you cannot just skip them).

Symptom:
```
requests.exceptions.HTTPError: Transient error uploading file
'.../CarEnv/Physics/__init__.py'. Status code: 501
```

## The fix: upload a tarball, extract on the studio

A tar archive is a single non-empty file; empty files ride safely *inside* it
and are recreated on extraction. This is the only method immune to the 501.

```
# on the code host (HPC login node), via c.call_command(..., login_shell=True):
tar czf ~/payload.tar.gz \
    --exclude=".git" --exclude=".pixi" --exclude="__pycache__" --exclude="*.pyc" \
    <dir1> <dir2> <file1> <file2>
```
Then, from the studio SDK python (see auth below):
```python
from lightning_sdk import Studio, Teamspace
s = Studio(name="<studio>", teamspace=Teamspace(name="<ts>", user="<owner>"))
s.upload_file(os.path.expanduser("~/payload.tar.gz"),
              remote_path="payload.tar.gz", progress_bar=False)   # non-empty → OK
out = s.run("tar xzf payload.tar.gz && rm payload.tar.gz && echo OK")
# verify empties survived:
print(s.run("find <dir1> -type f -empty | wc -l"))
```
`s.run("<cmd>")` executes a shell command **on the studio** and returns stdout —
use it to extract and verify.

## Prerequisites, in order

**1. Auth env vars must be EXPORTED.** On the HPC side the key typically lives
in `~/.zshrc` and is set-but-not-exported, so a Python child process can't see
it. Always prefix remote commands with:
```
source ~/.zshrc 2>/dev/null; export LIGHTNING_API_KEY LIGHTNING_USER_ID; ...
```

**2. Use the real SDK interpreter, not a hand-rolled venv.** The user's current
SDK is usually installed via `uv tool` (Python 3.13/3.14, recent `lightning_sdk`).
A throwaway `python3.9 -m venv` pins an *old* `lightning_sdk` and wastes a debug
cycle. Find the real one:
```
lightning --help              # confirms the CLI version
readlink -f $(which lightning)  # shebang points at the SDK python, e.g.
# /home/<user>/.local/share/uv/tools/lightning-sdk/bin/python
```
Run upload scripts with that interpreter.

**3. Resolve the teamspace by user vs org.** `Teamspace(name=..., org=...)`
fails if the owner is a *personal* account. If `org='<name>'` errors with
"Organization '<name>' does not exist", it's a user:
```python
Teamspace(name="dev", user="vaishnavahari")   # personal owner
Teamspace(name="dev", org="acme")             # true organization
```
The CLI `lit://` URL is `lit://<owner>/<teamspace>/studios/<studio>/<path>`,
using the same owner slug.

**4. The studio must be Running to accept uploads.** Start and wait:
```python
if str(s.status) != "Status.Running":
    s.start()
    while str(s.status) != "Status.Running":
        time.sleep(6)
```
A studio that is Stopped/asleep also refuses SSH (`Permission denied (publickey)`).

## What to exclude

Uploads are usually dominated by junk, not code. Exclude aggressively:
`.pixi` / `.venv` (rebuild from lock on the studio), `.git`, `__pycache__`,
`*.pyc`, old run checkpoints (`exp-*/checkpoints`, `*.zip` model dumps), PDFs.
A real code tree is typically a few MB; if the tar is hundreds of MB, something
heavy leaked in — list the tar (`tar tzf`) and re-check the excludes.

Note: **empty directories do not upload** by any method (nothing to archive).
If the job needs an empty dir, create it on the studio with `s.run("mkdir -p <d>")`.

## Studio name collisions & reuse (decide BEFORE uploading)

`Studio(name=..., create_ok=True)` is get-or-create: it silently **reuses** an
existing studio of that name rather than erroring. A studio is a persistent,
mutable, shared workspace — one filesystem, reused across experiments and jobs —
so uploading into an existing one can clobber another experiment's code or land
files on top of stale ones. Never upload blind. Inspect first, then pick a lane.

**Step 1 — inspect what's already there** (see `studio_state_command` helper):
does the studio exist, what is its status, is a job actively using it, and does
the target path already hold files?

**Step 2 — pick a strategy by what you find:**

- **Studio absent** → create it (`create_ok=True`) and upload. Clean.
- **Exists, empty (or only `main.py`)** → safe to upload as-is.
- **Exists, holds a DIFFERENT experiment's code** → do NOT overwrite in place.
  Prefer one of:
  - **Namespace by subfolder** — extract under `~/<exp-name>/` (pass
    `remote_extract_dir="<exp>"`), so experiments coexist. Jobs then run with
    that subdir as CWD. This is the safest default for a shared studio.
  - **Separate studio per experiment** — `Studio(name="myproj-exp5", ...)`.
    Cheapest to reason about; a stopped studio costs ~nothing. Use when
    experiments have divergent envs or you want isolation.
- **A job is actively RUNNING against it** → uploading is still safe for the
  *running* job (jobs execute on a separate machine against a snapshot taken at
  submit time — later uploads don't reach an in-flight job), BUT you will mutate
  the studio filesystem the user may be watching, and the NEXT job will pick up
  your changes. If unsure, use a subfolder or a separate studio; don't overwrite
  a path another experiment's next job depends on.
- **Path already occupied by an OLD version of the same code** → clear it
  explicitly before extracting so deleted files don't linger:
  `s.run("rm -rf <dir> && mkdir -p <dir>")`, then extract. (Tar extraction
  overwrites matching files but does NOT remove files you deleted locally.)

**Never delete a studio to "reset" it.** A stopped studio is nearly free and may
hold another experiment's outputs/logs. Stop it, don't delete it. Delete only
when the whole project is done and outputs are harvested.

**Rule of thumb:** one studio can host many experiments **if** each lives in its
own subfolder; reach for a second studio only when envs diverge or you need hard
isolation.

## Deprecated paths (don't reach for these)

- `lightning folder upload ...` → deprecated; the CLI itself redirects you to
  `lightning studio cp -r`. But `studio cp -r` still hits the zero-byte 501, so
  it is NOT a workaround — only the tarball is.

## One-call helper (kernel.py)

Loading this skill defines `build_tarball_upload_command(...)` in your python
kernel. It returns a ready-to-run bash command implementing the entire
tar -> upload -> extract -> verify sequence (including starting the studio and
exporting auth). Build it in a `python` cell, then run it via the repl tool:

```python
# python tool: build the command string
cmd = build_tarball_upload_command(
    host_dir="$HOME/myRacer",
    includes=["carenv", "pixi.lock", "pyproject.toml", "registration.yaml"],
    studio="myRacer", teamspace="dev", owner="vaishnavahari", owner_kind="user",
    sdk_python="/home/yn030245/.local/share/uv/tools/lightning-sdk/bin/python",
)
open("handoff/upload_cmd.txt", "w").write(cmd)
```
```python
# repl tool: dispatch it on the code host
c = host.compute.create("ssh:<host>")
cmd = open("handoff/upload_cmd.txt").read()
r = c.call_command(cmd, intent="Tarball-upload code tree to studio",
                   login_shell=True, timeout_seconds=600)
print(r["stdout"])   # expect STUDIO Running / UPLOADED / EXTRACT OK / FILES n / EMPTY_PRESERVED >0
```
Pass `owner_kind="org"` for a true organization; omit `sdk_python` to
auto-discover it from the `lightning` CLI shebang.

## Verify after upload

```python
print(s.run("find <dir> -type f | wc -l"))          # file count
print(s.run("find <dir> -type f -empty | wc -l"))   # empties preserved (>0 expected for packages)
print(s.run("find <dir> -name __init__.py | wc -l"))# package markers present
```
