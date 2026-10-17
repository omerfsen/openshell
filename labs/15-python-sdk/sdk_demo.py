"""Drive OpenShell from Python: create a sandbox from a template, run a
command in it, then delete it. Uses the gateway the CLI registered."""

import sys

from openshell import SandboxClient

WORKSPACE = "default"
TEMPLATE = sys.argv[1] if len(sys.argv) > 1 else "training-tools"
NAME = sys.argv[2] if len(sys.argv) > 2 else "lab15-sdk"

with SandboxClient.from_active_cluster() as client:
    print(f"gateway version: {client.health().version}")

    sandbox = client.create_from_template(
        workspace=WORKSPACE,
        workload_template=TEMPLATE,
        name=NAME,
        labels={"course": "openshell-training", "lab": "15"},
    )
    client.wait_ready(sandbox.name, workspace=WORKSPACE, timeout_seconds=180)
    print(f"sandbox ready: {sandbox.name}")

    try:
        result = client.exec(
            sandbox.name,
            ["sh", "-c", "id -un; cat /etc/os-release | head -1"],
            workspace=WORKSPACE,
            no_login_shell=True,
        )
        print(result.stdout, end="")
        print(f"exit code: {result.exit_code}")
    finally:
        deletion = client.delete(sandbox.name, workspace=WORKSPACE)
        client.wait_deleted(
            sandbox.name,
            workspace=WORKSPACE,
            expected_sandbox_id=deletion.sandbox_id,
        )
        print("sandbox deleted")
