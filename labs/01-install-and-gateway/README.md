# Lab 01 — Install OpenShell and meet the gateway

**Goal:** install OpenShell **0.1.4**, understand what the installer put on the machine, and
learn to inspect and configure the gateway.
**Time:** ~15 minutes. **Prerequisite:** [Lab 00](../00-prepare-ubuntu/README.md).

## Concepts

OpenShell has a small number of moving parts. You will meet all of them in this course:

```text
  you ──► openshell CLI ──mTLS──► GATEWAY (control plane, systemd user service)
                                     │  stores sandboxes, policies, providers
                                     │  asks a compute driver (Docker) to build:
                                     ▼
              ┌──────────── sandbox boundary ────────────┐
              │ SUPERVISOR container (trusted)           │◄── policy, credentials, logs
              │   ▲ authenticated Unix socket            │
              │   ▼                                      │
              │ WORKLOAD container (no network device)   │
              │   openshell-sandbox ─► your agent        │
              └──────────────────────────────────────────┘
```

- **Gateway** (`openshell-gateway`): remembers every sandbox, delivers policy and
  credentials, authenticates you. On Ubuntu it runs as a **systemd user service** on
  `https://127.0.0.1:17670`.
- **Compute driver**: builds the boundary. Here it is Docker. Podman, Kubernetes, and MicroVM
  are the alternatives.
- **Supervisor**: the trusted side. It decides every network request, injects credentials,
  resolves DNS.
- **Sandbox runtime** (`openshell-sandbox`): sits inside the workload next to the agent, owns
  its processes, and hands every TCP connect and DNS lookup to the supervisor. It never makes
  policy decisions.
- **Policy prover** (`openshell-prover`): formal verification of policies (Lab 11).

## 1. Install a pinned version

The course is written and tested against **OpenShell 0.1.4**. Pin it so a newer weekly
release does not change the behavior under your feet:

```shell
curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/v0.1.4/install.sh |
  OPENSHELL_VERSION=v0.1.4 sh
```

The installer, on Ubuntu:

1. downloads the `openshell_0.1.4-1_<arch>.deb` package from the GitHub release and installs
   it with `apt`, which gives you `/usr/bin/openshell`, `/usr/bin/openshell-gateway`, and
   `/usr/bin/openshell-prover`;
2. enables and starts the `openshell-gateway` systemd **user** unit;
3. registers that gateway with the CLI under the name `openshell`.

Read the script before piping it to `sh` if you prefer: `curl -LsSf <url> | less`.

## 2. Verify

```shell
openshell --version          # openshell 0.1.4
openshell status
```

```text
Server Status

  Gateway: openshell
  Server: https://127.0.0.1:17670
  Status: Connected
  Authentication: Authenticated (mTLS transport)
  Version: 0.1.4
```

If `status` says `No gateway configured`, register it yourself. This is the step the
installer normally does:

```shell
openshell gateway add https://127.0.0.1:17670 --local --name openshell
```

## 3. Look around the gateway

```shell
openshell gateway list        # registered gateways, * marks the active one
openshell gateway info        # live runtime info: version, compute drivers, extensions
openshell doctor check        # host prerequisites as the gateway sees them
systemctl --user status openshell-gateway
journalctl --user -u openshell-gateway -n 50
```

`gateway info` should list `docker` under **Compute drivers**. The gateway auto-detected the
Docker socket.

Where things live:

| Path | What |
|---|---|
| `~/.config/openshell/gateway.toml` | Optional gateway config. Absent means built-in defaults. |
| `~/.config/openshell/gateway.env` | Optional environment for the service |
| `~/.config/openshell/gateways/` | CLI gateway registrations |
| `~/.local/state/openshell/` | Gateway database and TLS material (CA, server, client certs) |

To keep the gateway running after you log out (useful on a server): `sudo loginctl enable-linger $USER`.

## 4. Configure the gateway (optional but instructive)

[`gateway.toml`](gateway.toml) in this folder is a small schema-version-2 config that pins the
Docker driver and makes the training tools image (Lab 03) the default sandbox image.
**Always preflight** a config before restarting: preflight validates without changing the file.

```shell
openshell-gateway config preflight --path labs/01-install-and-gateway/gateway.toml && echo valid
```

See what a broken file looks like. `compute_drivers = [...]` is the legacy v1 syntax:

```shell
sed 's/compute_driver = "docker"/compute_drivers = ["docker"]/' \
  labs/01-install-and-gateway/gateway.toml > /tmp/bad.toml
openshell-gateway config preflight --path /tmp/bad.toml
# × gateway config preflight failed: ... category=malformed ... the file was preserved unchanged
```

To apply it (do this after Lab 03, once the tools image exists):

```shell
mkdir -p ~/.config/openshell
cp labs/01-install-and-gateway/gateway.toml ~/.config/openshell/gateway.toml
systemctl --user restart openshell-gateway
openshell status
```

Remove the file and restart to go back to defaults. The rest of the course passes `--from`
explicitly, so it works either way.

## Telemetry

OpenShell sends anonymous operational counts (no names, paths, prompts, or credentials). To
turn it off, add `OPENSHELL_TELEMETRY_ENABLED=false` to `~/.config/openshell/gateway.env` and
restart the service.

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=01          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=01     # asciinema
labs/01-install-and-gateway/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/01-install-and-gateway/test.bats
```

**Next:** [Lab 02 — Sandbox basics](../02-sandbox-basics/README.md)
