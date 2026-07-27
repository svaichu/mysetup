"""Command builders for launching/monitoring Lightning AI jobs over the
ssh compute provider. Every function returns a shell COMMAND STRING to pass to
`c.call_command(cmd, intent=..., login_shell=True)`. Stdlib only."""

import base64

DEFAULT_SDK_PY = "/home/zeus/miniconda3/envs/cloudspace/bin/python"


def wrap_python_command(py_source, interpreter=None):
    """Base64-encode a python snippet and return a command that decodes+runs it
    with `interpreter`, sidestepping shell quoting of the payload."""
    if interpreter is None:
        interpreter = DEFAULT_SDK_PY
    b64 = base64.b64encode(py_source.encode()).decode()
    return "echo " + b64 + " | base64 -d | " + interpreter


def discover_env_command():
    """Command that prints the SDK python (has lightning_sdk), candidate training
    venvs, and pwd on a studio. Run this first on an unfamiliar studio."""
    return (
        'echo "== SDK python (has lightning_sdk) =="; '
        'for p in ' + DEFAULT_SDK_PY + ' "$(which python)"; do '
        '  "$p" -c "import lightning_sdk,sys;print(sys.executable, lightning_sdk.__version__)" 2>/dev/null && break; '
        'done; '
        'echo "== training venv candidates =="; '
        'ls -d ~/*/.venv/bin/python ~/*/*/.venv/bin/python 2>/dev/null; '
        'echo "== pwd =="; pwd'
    )


def build_submit_command(name, workdir, train_cmd, machine="T4",
                         sdk_py=None, forward_env=None, max_runtime=3600):
    """Command that submits a Lightning Job against the current Studio().

    name        unique job name within the teamspace
    workdir     absolute dir to cd into before running (job cwd)
    train_cmd   the training invocation, e.g. "<venv_py> train.py --epochs 150"
    machine     Machine enum member name: CPU/T4/L4/L40S/A10G/A100/H100/H200/B200
    sdk_py      path to the python that has lightning_sdk (default cloudspace)
    forward_env list of env var NAMES to forward into the job (e.g. W&B keys)
    max_runtime seconds; job is killed past this
    """
    if sdk_py is None:
        sdk_py = DEFAULT_SDK_PY
    if forward_env is None:
        forward_env = ["WANDB_API_KEY", "WANDB_USERNAME"]
    full_cmd = "cd " + workdir + " && " + train_cmd
    src = (
        "import os\n"
        "from lightning_sdk import Job, Machine, Studio\n"
        "keys = " + repr(list(forward_env)) + "\n"
        "env = {k: os.environ[k] for k in keys if k in os.environ}\n"
        "job = Job.run(name=" + repr(name) + ", machine=Machine." + machine + ",\n"
        "              command=" + repr(full_cmd) + ", studio=Studio(),\n"
        "              env=env, max_runtime=" + repr(int(max_runtime)) + ")\n"
        "print('JOB_NAME', job.name)\n"
        "print('STATUS', job.status)\n"
        "try:\n"
        "    print('JOB_LINK', job.link)\n"
        "except Exception as e:\n"
        "    print('JOB_LINK_ERR', e)\n"
    )
    return wrap_python_command(src, sdk_py)


def build_status_command(name, sdk_py=None, with_logs=False):
    """Command that prints a job's status. If with_logs=True and the job is
    terminal, also prints full logs and artifact_path (logs raise while running)."""
    if sdk_py is None:
        sdk_py = DEFAULT_SDK_PY
    src = (
        "from lightning_sdk import Job\n"
        "j = Job(name=" + repr(name) + ")\n"
        "print('STATUS', j.status)\n"
    )
    if with_logs:
        src += (
            "if str(j.status).lower() in ('completed','stopped','failed','error','success'):\n"
            "    print('=== LOG ==='); print(j.logs or '')\n"
            "    print('=== ARTIFACT_PATH ===', j.artifact_path)\n"
        )
    return wrap_python_command(src, sdk_py)


def job_artifacts_root(name):
    """The job artifact mirror root on the studio filesystem. Job outputs land
    under <root>/<mirror-of-job-cwd>/... , NOT in the studio working tree."""
    return "/teamspace/jobs/" + name + "/artifacts"


def build_find_outputs_command(name, patterns=None, maxdepth=8):
    """Command that finds output files under a job's artifact mirror."""
    if patterns is None:
        patterns = ["*.pt", "*.ckpt", "output.log", "*.json"]
    expr = " -o ".join('-name "' + p + '"' for p in patterns)
    root = job_artifacts_root(name)
    return "find " + root + " -maxdepth " + str(int(maxdepth)) + " \\( " + expr + " \\) 2>/dev/null"


def build_fetch_command(remote_path):
    """Command that base64-encodes a remote file to stdout for retrieval when
    c.download is unavailable. Decode the stdout with base64.b64decode and write
    bytes locally. Suitable for small files (KBs to a few MB)."""
    return "base64 -w0 " + remote_path
