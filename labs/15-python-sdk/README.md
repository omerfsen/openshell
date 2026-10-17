# Lab 15 — The Python SDK

**Goal:** drive OpenShell from code: create a sandbox, run a command, and clean up, using
the same gateway registration the CLI uses.
**Time:** ~15 minutes. **Prerequisite:** [Lab 13](../13-templates-labels-settings/README.md)
(templates).

## Concepts

OpenShell's API is gRPC. SDKs wrap it for **Python** (`openshell` on PyPI), **TypeScript**
(`@nvidia/openshell-sdk`), **Go** (`github.com/NVIDIA/OpenShell/sdk/go`), and **Rust**
(`openshell-sdk`). Use the SDK version that matches your gateway: **0.1.4** here.

`SandboxClient.from_active_cluster()` reads the gateway the CLI selected (endpoint, mTLS
files, OIDC tokens), so a script needs no extra configuration on a machine where the CLI
works. Every call takes an explicit `workspace` (`default` on a local gateway).

Typical uses: CI jobs that run untrusted code in a fresh sandbox, notebooks that fan out
experiments, a platform service that creates one sandbox per user request.

## 1. Install the SDK in a virtual environment

```shell
python3 -m venv ~/.venvs/openshell
~/.venvs/openshell/bin/pip install openshell==0.1.4
```

(The package needs Python 3.11+. Ubuntu 24.04's `python3` is 3.12. `sudo apt install
python3-venv` if `venv` is missing.)

## 2. Create a template for the script to use

```shell
openshell sandbox template create training-tools --image openshell-training/tools:0.1.4
```

## 3. Run the demo

[`sdk_demo.py`](sdk_demo.py) checks the gateway version, creates a labeled sandbox from the
template, waits for `Ready`, runs a command, prints its output and exit code, and deletes the
sandbox, even if the command fails:

```shell
~/.venvs/openshell/bin/python labs/15-python-sdk/sdk_demo.py training-tools sdk-demo
```

```text
gateway version: 0.1.4
sandbox ready: sdk-demo
ubuntu
PRETTY_NAME="Ubuntu 24.04.5 LTS"
exit code: 0
sandbox deleted
```

The key calls:

```python
with SandboxClient.from_active_cluster() as client:
    sandbox = client.create_from_template(workspace="default", workload_template="training-tools",
                                          name="sdk-demo", labels={"lab": "15"})
    client.wait_ready(sandbox.name, workspace="default", timeout_seconds=180)
    result = client.exec(sandbox.name, ["sh", "-c", "id -un"], workspace="default", no_login_shell=True)
    deletion = client.delete(sandbox.name, workspace="default")
    client.wait_deleted(sandbox.name, workspace="default", expected_sandbox_id=deletion.sandbox_id)
```

`client.create(workspace=..., name=..., labels=..., service_exposures=[...])` creates a sandbox
from a raw `SandboxSpec`. `client.create_session()` returns an object that remembers the name
and workspace for repeated `exec`, `stop`, `start`, and `delete`. List calls return lazy
pagers, and `list_all()` fetches everything.

## 4. Clean up

```shell
openshell sandbox template delete training-tools
```

## Exercises

1. Change the demo to run `python3 -c "print(2**100)"` and print `result.stdout`.
2. Use `client.list_all(workspace="default", label_selector="lab=15")` while the sandbox
   exists.

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=15          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=15     # asciinema
labs/15-python-sdk/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/15-python-sdk/test.bats      # creates its own venv; needs network to PyPI
```

**Next:** [Lab 16 — Protocol-aware rules: TCP, WebSocket, GraphQL, MCP](../16-protocol-rules/README.md)
