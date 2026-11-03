# Lab 19 (bonus) — Upgrade to 0.1.6 and what's new

**Goal:** move your machine from OpenShell **0.1.4** to **0.1.6**, check that nothing broke,
and try the new features you can run on one machine.
**Time:** ~20 minutes. **Prerequisite:** the course (at least Labs 01–07).

Labs 00–18 are written and tested against 0.1.4. This lab is the exception: it upgrades the
host, so run it last, or roll back afterwards (section 7).

## What changed between 0.1.4 and 0.1.6

Two releases: [v0.1.5](https://github.com/NVIDIA/OpenShell/releases/tag/v0.1.5)
(2026-10-20) and [v0.1.6](https://github.com/NVIDIA/OpenShell/releases/tag/v0.1.6)
(2026-10-27). The ones this lab covers:

| Release | Change | Section |
|---|---|---|
| 0.1.6 | Gateways refuse to start with no authentication configured | 1 |
| 0.1.5, 0.1.6 | Gateway audit events for rejected and accepted credentials | 2 |
| 0.1.5 | `sandbox create --env-from` and `--annotation` | 3 |
| 0.1.5 | Reserved `internal.openshell.ai/` annotation prefix | 3 |
| 0.1.6 | `sandbox suspend` / `sandbox resume` (driver permitting) | 4 |
| 0.1.5 | Push-based config delivery: policy changes in about a second | 5 |

Others you should know about but cannot try on one Docker host: OCSF files renamed from
`openshell-ocsf.*.log` to `*.jsonl` (update your log collector patterns), OCSF events over
OTLP, MicroVM bind mounts, a shared supervisor on Kubernetes (experimental), and new Helm
values. Read both release notes before upgrading a real deployment.

## 1. Upgrade

Clean up first, so no 0.1.4 sandbox is left running when the supervisor changes. 0.1.6
changes which side opens the control connection, and the release notes say to upgrade the
gateway and the sandbox runtime together:

```shell
scripts/cleanup.sh
mkdir -p ~/openshell-0.1.4-backup &&
  cp -a ~/.local/state/openshell ~/.config/openshell ~/openshell-0.1.4-backup/   # for section 7
curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/v0.1.6/install.sh |
  OPENSHELL_VERSION=v0.1.6 sh
openshell --version          # openshell 0.1.6
openshell status
```

```text
  Status: Connected
  Authentication: Authenticated (mTLS transport)
  Version: 0.1.6
```

The installer upgrades the `.deb`, restarts the user service and registers the gateway again
(`local gateway already exists; removing and re-adding it`).

**The new auth rule.** 0.1.6 gateways refuse to start unless OIDC, mTLS, or gateway JWTs are
configured. The local Debian/Ubuntu gateway already uses mTLS, so nothing changes here. The
gateway log says so at startup:

```shell
journalctl --user -u openshell-gateway -b | grep 'authentication enabled'
# INFO openshell_server::cli: mTLS user authentication enabled
```

A gateway you configured yourself with no auth at all will stop starting after the upgrade.
For trusted local development only, `allow_unauthenticated_users = true` under
`[openshell.gateway.auth]` brings back the old behavior.

## 2. The gateway audits who it lets in

The gateway now writes OCSF Authentication events. Send it a request with no client
certificate and no token. curl speaks enough gRPC for this:

```shell
curl -sk --http2 -i -X POST -H 'content-type: application/grpc' -H 'te: trailers' \
  --data-binary @/dev/null https://127.0.0.1:17670/openshell.v1.OpenShell/ListSandboxes |
  grep -iE 'grpc-(status|message)'
```

```text
grpc-status: 16
grpc-message: missing%20authorization%20header
```

HTTP 200 is normal for gRPC. The real answer is the `grpc-status` trailer: 16 is
`UNAUTHENTICATED`. The gateway log has the audit line:

```shell
journalctl --user -u openshell-gateway --since -2min | grep 'AUTH:LOGON'
```

```text
OCSF AUTH:LOGON [LOW] DENIED unknown from 127.0.0.1:51836 [op:/openshell.v1.OpenShell/ListSandboxes reason:missing_credential]
OCSF AUTH:LOGON [INFO] ALLOWED user:openshell-client from 127.0.0.1:52832 [protocol:mtls op:/openshell.v1.OpenShell/GetGatewayInfo]
```

You also see `ALLOWED` lines: the first time the gateway accepts a credential (your CLI's
client certificate, a sandbox's JWT), it records one logon. Repeated requests with the same
credential log nothing, so supervisor polling does not flood the log. The events never
contain the credential itself. In a SIEM, select rejected requests with `status_id: 2`.

## 3. Two new `sandbox create` flags

**`--env-from KEY[=ENVVAR]`** sets a sandbox environment variable from the CLI's own
environment, so the value never appears on the command line, in shell history, or in `ps`:

```shell
export LAB19_TOKEN=demo-value-19
openshell sandbox create --name lab19-new --from openshell-training/tools:0.1.4 \
  --no-auto-providers --detach \
  --env-from LAB19_TOKEN --env-from API_TOKEN=LAB19_TOKEN \
  --annotation team=platform --annotation 'note=has spaces / and ='
openshell sandbox exec -n lab19-new --no-login-shell -- \
  sh -c 'echo "LAB19_TOKEN=$LAB19_TOKEN API_TOKEN=$API_TOKEN"'
# LAB19_TOKEN=demo-value-19 API_TOKEN=demo-value-19
```

`API_TOKEN=LAB19_TOKEN` renames on the way in. An unset source variable is refused before
anything is created:

```text
$ openshell sandbox create ... --env-from NOPE_NOT_SET
Error:   × --env-from source environment variable 'NOPE_NOT_SET' is not set or is not valid Unicode
```

The CLI notices the name and warns you:

```text
⚠ LAB19_TOKEN looks like a credential passed as a plain environment variable.
  The agent inside the sandbox can read this value directly.
  To hide it from the agent, use a provider instead of --env.
```

That warning is right: this is still a plain environment variable, and the agent can read it. For a real secret, a
provider (Lab 08) is better, because the agent only ever sees a placeholder.

**`--annotation KEY=VALUE`** attaches non-secret metadata. Values may contain `/`, spaces and
`=`:

```shell
openshell sandbox get lab19-new | sed -n '/Annotations/,/Conditions/p' | grep -v internal.openshell
```

```text
  Annotations:
    note: has spaces / and =
    team: platform
```

The `internal.openshell.ai/` keys you filtered out belong to OpenShell itself (auth epoch,
token ID, runtime generation). Since 0.1.5 you cannot set them:

```text
$ openshell sandbox create ... --annotation internal.openshell.ai/x=1
Error:   × code: 'Client specified an invalid argument', message: "annotations key
  │ 'internal.openshell.ai/x' uses the reserved 'internal.openshell.ai/' prefix"
```

## 4. Suspend and resume

0.1.6 adds `openshell sandbox suspend` (keep the sandbox's memory state, free its CPU) and
`sandbox resume`. It needs a compute driver that supports it, and Docker does not:

```shell
openshell sandbox suspend lab19-new
```

```text
Error:   × code: 'The system is not in a state required for the operation's
  │ execution', message: "compute driver does not support sandbox suspend"
```

That is the documented behavior: drivers without support return an error, and the sandbox
keeps running. Use `sandbox stop` / `start` (Lab 02) on Docker.

## 5. Policy changes in about a second

Up to 0.1.4, supervisors **poll** the gateway for policy and settings about every 10 seconds.
That is why Lab 07's `--wait` takes so long. 0.1.5 adds **push** delivery over the existing
supervisor session. Polling is still the default, so measure it first:

```shell
openshell sandbox create --name lab19-cfg --from openshell-training/tools:0.1.4 \
  --policy labs/07-policy-lifecycle/policy.yaml --no-auto-providers --detach
time openshell policy update lab19-cfg --rule-name r1 --binary /usr/bin/curl \
  --add-endpoint example1.com:443 --wait
```

Expect anything up to about 10 seconds, depending on where the change lands in the poll
cycle. On the test machine, three runs back to back took **10.1 s** each, and the recorded
solution took 4.1 s. Now switch the gateway to push.
[`gateway-push.toml`](gateway-push.toml) is the Lab 01 config plus one line,
`config_delivery_mode = "push"`. If you already have a `gateway.toml`, add that line under
`[openshell.gateway]` instead of copying:

```shell
openshell-gateway config preflight --path labs/19-whats-new-0.1.6/gateway-push.toml && echo valid
cp labs/19-whats-new-0.1.6/gateway-push.toml ~/.config/openshell/gateway.toml
systemctl --user restart openshell-gateway
openshell status | grep Status        # wait for Connected, and for lab19-cfg to be Ready
time openshell policy update lab19-cfg --rule-name r2 --binary /usr/bin/curl \
  --add-endpoint example2.com:443 --wait
```

Every run, including the recording: **1.1 s**. Supervisors that cannot take pushed
config keep polling, so mixing versions is safe. Remove the file and restart the gateway to
go back to polling.

## 6. Clean up

```shell
openshell sandbox delete lab19-new lab19-cfg
rm ~/.config/openshell/gateway.toml && systemctl --user restart openshell-gateway
```

## 7. Roll back to 0.1.4 (to redo Labs 00–18)

The installer only moves forward. Rerunning it with `OPENSHELL_VERSION=v0.1.4` downloads the
package and then stops, because apt will not downgrade without being told to:

```text
E: Packages were downgraded and -y was used without --allow-downgrades.
```

The host stays on 0.1.6. Download the 0.1.4 package yourself, check it, and allow the
downgrade explicitly:

```shell
scripts/cleanup.sh
mkdir -p /tmp/os014 && cd /tmp/os014
gh release download v0.1.4 -R NVIDIA/OpenShell \
  -p 'openshell_0.1.4-1_amd64.deb' -p 'openshell-checksums-sha256.txt'
grep 'openshell_0.1.4-1_amd64.deb' openshell-checksums-sha256.txt | sha256sum -c -
sudo apt-get install -y --allow-downgrades ./openshell_0.1.4-1_amd64.deb
systemctl --user restart openshell-gateway
cd - && openshell --version && openshell status
```

On arm64, use `openshell_0.1.4-1_arm64.deb`. Without `gh`, download the same two files from
the [v0.1.4 release page](https://github.com/NVIDIA/OpenShell/releases/tag/v0.1.4).

On the test machine, the 0.1.4 gateway started on the database 0.1.6 had used, and the Lab 02
and Lab 07 checks passed again (16 of 16). Run `scripts/cleanup.sh` before downgrading, so no
sandbox created by 0.1.6 is left behind. If the gateway refuses to start, stop it, restore
the backup from section 1 into `~/.local/state/openshell` and `~/.config/openshell`, and
start it again.

## Watch the solution

Every step of this lab, typed and run against a real 0.1.6 gateway:

```shell
make replay LAB=19          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=19     # asciinema
labs/19-whats-new-0.1.6/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

The solution starts after the upgrade: it does not run the installer.

## Check your work

```shell
bats labs/19-whats-new-0.1.6/test.bats
```
