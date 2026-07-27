---
name: lightning-ai-jobs
description: Launch and monitor GPU/CPU jobs on a Lightning AI studio via the SSH compute provider (host.compute + lightning_sdk Job.run). Covers submit, machine types (T4/A100/H100/...), status polling, why logs are terminal-only, the /teamspace/jobs artifact filesystem model (where outputs actually land, and the live-but-lagged sync), retrieving outputs when c.download fails, and using W&B as the live-metrics channel. Use when the studio itself is CPU-only and real training must run as a Lightning Job on a separate machine, or the user says "run as a lightning job", "submit to the studio", "on a T4/A100".
---

# Lightning AI Jobs

Launch async GPU/CPU workloads on a **Lightning AI studio** from Claude Science.
The studio is reached through an SSH compute provider (`ssh:<studio-name>`); the
Lightning SDK lives **on the studio**, and jobs run on **separate machines**
against a snapshot of the studio. This skill encodes the non-obvious behavior
(filesystem layout, log availability, retrieval) verified empirically.

Prerequisite: the SSH dispatch workflow — load `remote-compute-ssh` first. All
commands below run through `c = host.compute.create('ssh:<studio>')` in the
**repl tool**.

## Mental model (read this first)

- **Two Python interpreters on the studio, different jobs:**
  - **SDK python** — the studio's default `cloudspace` conda env, which has
    `lightning_sdk`. Use it to *submit and poll* jobs. Typical path:
    `/home/zeus/miniconda3/envs/cloudspace/bin/python`.
  - **Training python** — the project's own venv/conda env (e.g. `.venv/bin/python`),
    which has torch/wandb/your code. Use it as the *job command's* interpreter.
    It usually does NOT have `lightning_sdk`, and that is fine.
- **The studio is often CPU-only.** GPUs come from the job's `machine=`, not the
  studio. `torch.cuda.is_available()` in the studio shell being `False` is
  expected — the job runs elsewhere.
- **Jobs run against a snapshot**, on a different machine. Files a job writes do
  **not** appear in the studio's working tree. They land in the job's artifact
  mirror (see "Where outputs go").

## Step 0 — discover the studio's interpreters (don't hardcode)

This skill is studio-agnostic. On a new studio, find the two pythons:

```python
# repl tool
c = host.compute.create('ssh:<studio>')          # your provider name
r = c.call_command(
    'echo "== SDK python (has lightning_sdk) =="; '
    'for p in /home/zeus/miniconda3/envs/cloudspace/bin/python "$(which python)"; do '
    '  "$p" -c "import lightning_sdk,sys;print(sys.executable, lightning_sdk.__version__)" 2>/dev/null && break; '
    'done; '
    'echo "== training venv candidates =="; '
    'ls -d ~/*/.venv/bin/python ~/*/*/.venv/bin/python 2>/dev/null; '
    'echo "== pwd =="; pwd',
    intent="Discover SDK python and training venv on the studio", login_shell=True)
print(r["stdout"])
```

Record what you find in `compute_details` for the provider so the next session skips this.

## Step 1 — submit a job

`Job.run` signature (verified): `Job.run(name, machine, command=, studio=, image=,
env=, teamspace=, org=, user=, cloud=, interruptible=, max_runtime=, entrypoint=,
path_mappings=, reuse_snapshot=, ...)`. `studio` and `image` are mutually
exclusive; with a studio, `command` is required.

Use `Studio()` with no args — it binds to the **current** studio, so the same
code works from any studio. Names must be unique within the teamspace.

Quoting is the main hazard. Base64-encode a small launcher script and decode it
on the remote to avoid shell-escaping the training command:

```python
# repl tool
import base64, time
SDK_PY  = "/home/zeus/miniconda3/envs/cloudspace/bin/python"   # from Step 0
VENV_PY = "/teamspace/studios/this_studio/<repo>/.venv/bin/python"
WORKDIR = "/teamspace/studios/this_studio/<repo>/<subdir>"
NAME    = f"myjob-{int(time.time())}"                          # unique

train = f"cd {WORKDIR} && {VENV_PY} train.py --epochs 150 --device cuda"

launcher = (
    "import os\n"
    "from lightning_sdk import Job, Machine, Studio\n"
    "env = {k: os.environ[k] for k in ['WANDB_API_KEY','WANDB_USERNAME'] if k in os.environ}\n"
    f"job = Job.run(name={NAME!r}, machine=Machine.T4, command={train!r},\n"
    "              studio=Studio(), env=env, max_runtime=3600)\n"
    "print('JOB_NAME', job.name); print('STATUS', job.status)\n"
)
b64 = base64.b64encode(launcher.encode()).decode()
r = c.call_command(f"echo {b64} | base64 -d | {SDK_PY}",
                   intent="Submit Lightning Job", login_shell=True)
print(r["stdout"])   # JOB_NAME ... / STATUS Pending
```

**Machine types** (`lightning_sdk.Machine` members): `CPU`, `T4`, `L4`, `L40S`,
`A10G`, `A100`, `H100`, `H200`, `B200`, and multi-GPU variants (e.g. `A100_X8`).
Pick the smallest that fits; a small MLP run finishes on `T4` for a few cents.

**W&B auth**: Lightning studios are usually pre-authenticated via env vars
(`WANDB_API_KEY`, `WANDB_USERNAME`, `LIGHTNING_API_KEY`). Forward the W&B ones to
the job through `env=` as above.

## The 60-second cap — never poll in a loop

`c.call_command` (host.compute SSH) **times out at 60s**. Do NOT put a
`while`/`sleep` polling loop inside one call. Submit in one call; poll status in
separate short calls, spacing them with a `bash sleep` between tool calls, or end
the turn and resume.

## Step 2 — poll status

```python
import base64
poll = f"from lightning_sdk import Job; print(Job(name={NAME!r}).status)"
b = base64.b64encode(poll.encode()).decode()
print(c.call_command(f"echo {b} | base64 -d | {SDK_PY}", intent="Poll job status", login_shell=True)["stdout"])
# Pending -> Running -> Completed / Stopped / Failed
```

`lightning job inspect <name>` (CLI, available in the cloudspace env) returns
status + machine + total_cost as JSON at any time and is a quick alternative.
`lightning job list` shows all jobs.

## Logs are TERMINAL-ONLY (this surprises people)

- The SDK's `Job(name=...).logs` **raises** `"Getting jobs logs while the job is
  pending or running is not supported yet!"` — it only returns text once the job
  is in a terminal state.
- The `lightning job` CLI has **no `logs` subcommand** (only `delete`, `inspect`,
  `list`, `run`, `stop`).

So there is **no live stdout** through the official interfaces. Two ways to watch
progress during a run:

1. **W&B — the real live channel** (preferred; see "Live monitoring").
2. **The filesystem mirror** — stdout the job writes syncs to the studio during
   the run, but **lagged** (tens of seconds), not a live tail.

After the job is terminal, fetch full stdout (`j.logs`) and `j.artifact_path`.

## Where outputs go (NOT the studio tree)

Because a job runs off a snapshot on another machine, anything it writes to its
working directory is **not** in the studio's live repo. It appears under the
**job artifact mirror**:

```
/teamspace/jobs/<JOB_NAME>/artifacts/<mirror-of-the-job-cwd>/...
```

`Job.artifact_path` returns `/teamspace/jobs/<JOB_NAME>/artifacts`. Example: a job
whose cwd was `.../<repo>/<subdir>` and that wrote `ckpts/model.pt` ends up at
`/teamspace/jobs/<JOB_NAME>/artifacts/<repo>/<subdir>/ckpts/model.pt`. A W&B run
dir written by the job lands under the same mirror as `.../wandb/run-*/`.

Locate outputs with `find /teamspace/jobs/<JOB_NAME>/artifacts -maxdepth 8 -name "*.pt"`.

**Live-but-lagged**: the mirror is populated *during* the run, with a sync delay
of tens of seconds — so a progress file or `output.log` can be tailed mid-run,
just not in real time. (Verified: a file being appended every 4s showed up
mid-run once the first sync landed.)

## Retrieving outputs — c.download FAILS here

`c.download(...)` errors with `no scratch_root configured` on this provider. For
small files (checkpoints, logs, configs — KBs to a few MB) pull them over the
command channel with base64:

```python
import base64, os
os.makedirs("out", exist_ok=True)
base = f"/teamspace/jobs/{NAME}/artifacts/<repo>/<subdir>/ckpts"
for f in ["model.pt", "log.txt"]:
    rr = c.call_command(f"base64 -w0 {base}/{f}", intent=f"Encode {f}", login_shell=True)
    open(f"out/{f}", "wb").write(base64.b64decode(rr["stdout"].strip()))
```

Then `save_artifacts([...])` locally. For large outputs, prefer having the job
push to cloud storage or a W&B artifact instead of pulling over SSH.

## Live monitoring via W&B (verified live)

W&B is the genuine real-time signal. The run registers in the W&B cloud the
moment `wandb.init()` fires and metrics stream to the backend while the Lightning
job is still `Running`. Query from the studio's training venv (which has `wandb`)
via `wandb.Api()`, finding the run in `api.runs("<entity>/<project>")`.

**Gotcha (verified):** for a *running* run, `run.summary` and `run.lastHistoryStep`
advance live, but `run.history()` returns 0 / stale — it is oriented toward the
finalized run. Use `run.summary` / `run.lastHistoryStep` for liveness, not
`run.history()`. Note the W&B entity may be a team (e.g. the API key's org), not
your personal username — resolve it from `WANDB_USERNAME` or `api.default_entity`.

If a W&B MCP connector is attached and authorized, `host.mcp("wandb", ...)`
(e.g. `get_run_history_tool`, `compare_runs_tool`) is a cleaner path than SSH for
reading finished-run metrics.

## Cleanup

Delete only *throwaway* probe jobs, and never a job the user cares about —
confirm first. `lightning job delete <name>`, or `Job(name=...).stop()` to halt a
running one. Close the compute session with `c.close()` when done.

## Command builders (kernel.py)

This skill ships stdlib-only builders that assemble the base64-wrapped commands
above, so you avoid quoting mistakes:
`build_submit_command`, `build_status_command`, `build_fetch_command`,
`job_artifacts_root`, `discover_env_command`. They return **command strings** —
pass them to `c.call_command(...)`. They auto-load into the python kernel; since
dispatch runs in the repl tool, either call them in a python cell and hand the
string across via `handoff/`, or paste the pattern above directly.
Run `help(build_submit_command)` for arguments.
