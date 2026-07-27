import base64
import shlex

DEFAULT_EXCLUDES = (".git", ".pixi", ".venv", "__pycache__", "*.pyc")
UV_LIGHTNING_HINT = "/home/<user>/.local/share/uv/tools/lightning-sdk/bin/python"


def build_tarball_upload_command(host_dir, includes, studio, teamspace, owner,
                                 owner_kind="user", sdk_python=None,
                                 remote_extract_dir=".", excludes=None,
                                 tar_name="payload.tar.gz", verify_dir=None):
    """Build a single bash command that tars a code tree on the host, uploads it
    to a Lightning studio as ONE archive (immune to the zero-byte-file 501),
    extracts it on the studio, and verifies. Returns a string to hand to
    `c.call_command(cmd, login_shell=True, timeout_seconds=...)` in the repl tool.

    host_dir: dir on the host to cd into (e.g. "$HOME/myRacer").
    includes: list of paths RELATIVE to host_dir to pack (dirs and/or files).
    studio/teamspace/owner: Lightning studio identity.
    owner_kind: "user" (personal account) or "org" (true organization).
    sdk_python: absolute path to the uv-installed SDK python; if None, the
        command discovers it from the `lightning` CLI shebang at runtime.
    remote_extract_dir: where to extract on the studio (default studio home).
    excludes: tar exclude globs (default .git/.pixi/.venv/__pycache__/*.pyc).
    verify_dir: path on the studio to count files/empties in after extraction
        (default: first entry of `includes`).
    """
    if excludes is None:
        excludes = list(DEFAULT_EXCLUDES)
    if verify_dir is None:
        verify_dir = includes[0] if includes else "."
    key = "user" if owner_kind == "user" else "org"

    py = (
        "import os\n"
        "from lightning_sdk import Studio, Teamspace\n"
        "ts = Teamspace(name=%r, %s=%r)\n"
        "s = Studio(name=%r, teamspace=ts)\n"
        "import time\n"
        "if str(s.status)!='Status.Running':\n"
        "    s.start()\n"
        "    for _ in range(60):\n"
        "        if str(s.status)=='Status.Running': break\n"
        "        time.sleep(6)\n"
        "print('STUDIO', s.status, flush=True)\n"
        "s.upload_file(os.path.expanduser('~/%s'), remote_path=%r, progress_bar=False)\n"
        "print('UPLOADED', flush=True)\n"
        "print('EXTRACT', s.run('mkdir -p %s && tar xzf %s -C %s && rm %s && echo OK'))\n"
        "print('FILES', s.run('find %s -type f | wc -l'))\n"
        "print('EMPTY_PRESERVED', s.run('find %s -type f -empty | wc -l'))\n"
        % (teamspace, key, owner, studio,
           tar_name, tar_name,
           remote_extract_dir, tar_name, remote_extract_dir, tar_name,
           verify_dir, verify_dir)
    )
    b64 = base64.b64encode(py.encode()).decode()

    excl = " ".join("--exclude=%s" % shlex.quote(e) for e in excludes)
    inc = " ".join(shlex.quote(p) for p in includes)
    pybin = sdk_python if sdk_python else "$(readlink -f $(command -v lightning))"

    cmd = (
        "source ~/.zshrc 2>/dev/null; export LIGHTNING_API_KEY LIGHTNING_USER_ID; "
        "set -e; cd %s; "
        "tar czf ~/%s %s %s; "
        "echo TARBALL_BYTES $(stat -c%%s ~/%s); "
        "echo %s | base64 -d | %s 2>&1 | tail -12"
        % (shlex.quote(host_dir), tar_name, excl, inc, tar_name, b64, pybin)
    )
    return cmd


def studio_state_command(studio, teamspace, owner, owner_kind="user",
                         sdk_python=None, check_paths=None):
    """Build a bash command that reports a studio's state BEFORE you upload:
    whether it exists, its status, any active jobs, and whether target paths are
    already occupied. Returns a string for `c.call_command(..., login_shell=True)`.

    check_paths: list of studio-relative paths to test for existing files
        (e.g. ["carenv", "exp-5"]). For each, prints a file count.
    Other args as in build_tarball_upload_command.
    """
    if check_paths is None:
        check_paths = []
    key = "user" if owner_kind == "user" else "org"

    checks = "\n".join(
        "print('PATH %s FILES', s.run('find %s -type f 2>/dev/null | wc -l'))"
        % (p, p) for p in check_paths
    )
    py = (
        "from lightning_sdk import Studio, Teamspace\n"
        "ts = Teamspace(name=%r, %s=%r)\n"
        "try:\n"
        "    s = Studio(name=%r, teamspace=ts, create_ok=False)\n"
        "    print('EXISTS True')\n"
        "    print('STATUS', s.status)\n"
        "    was_running = str(s.status)=='Status.Running'\n"
        "    if not was_running:\n"
        "        print('NOTE studio not running; start it to inspect the filesystem')\n"
        "    else:\n"
        "        print('HOME', s.run('ls -A ~ 2>/dev/null | head -40'))\n"
        "%s\n"
        "except Exception as e:\n"
        "    print('EXISTS False  (', str(e)[:80], ')')\n"
        "try:\n"
        "    from lightning_sdk import Job\n"
        "    jobs = Job.list(teamspace=ts)\n"
        "    active = [j for j in jobs if 'run' in str(getattr(j,'status','')).lower() or 'pend' in str(getattr(j,'status','')).lower()]\n"
        "    print('ACTIVE_JOBS', len(active))\n"
        "    for j in active[:10]:\n"
        "        print('  JOB', getattr(j,'name','?'), getattr(j,'status','?'))\n"
        "except Exception as e:\n"
        "    print('JOBS_UNKNOWN', str(e)[:80])\n"
        % (teamspace, key, owner, studio, ("    "+checks.replace("\n","\n    ")) if checks else "    pass")
    )
    b64 = base64.b64encode(py.encode()).decode()
    pybin = sdk_python if sdk_python else "$(readlink -f $(command -v lightning))"
    cmd = (
        "source ~/.zshrc 2>/dev/null; export LIGHTNING_API_KEY LIGHTNING_USER_ID; "
        "echo %s | base64 -d | %s 2>&1 | tail -40"
        % (b64, pybin)
    )
    return cmd
