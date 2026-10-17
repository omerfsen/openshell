# Lab 00 — Prepare a fresh Ubuntu 24.04 host

**Goal:** turn a brand-new Ubuntu 24.04 LTS machine into a host that can run OpenShell sandboxes.
**Time:** ~15 minutes. **You need:** `sudo` on the machine.

## Why this matters

OpenShell does not ship its own isolation kernel. It builds every sandbox from features of the
Linux kernel the host already runs (Landlock for files, seccomp for syscalls and network
mediation) and from a container runtime that creates the workload. On Ubuntu that runtime is
Docker Engine. If the kernel or Docker are too old, sandboxes refuse to start: OpenShell fails
closed rather than running an agent without its controls.

| Requirement | Minimum | Why |
|---|---|---|
| Ubuntu | 24.04 LTS, x86_64 or arm64 | Supported platform for the `.deb` package |
| Kernel | 6.2+ with Landlock enabled (24.04 ships 6.8) | Landlock ABI 3 confines filesystem access |
| Docker Engine | 28.0+ | The local gateway's compute driver |
| CPU / RAM / disk | 2 vCPU / 4 GB / 20 GB minimum; **2 vCPU / 8 GB / 30 GB recommended** | An idle sandbox (workload + supervisor container) uses ~20 MiB of RAM; images for the whole course are under 1 GB. The headroom is for real agents in Lab 17. |

## 1. Create the machine

Any of these gives you a clean Ubuntu 24.04:

- A cloud VM (AWS, GCP, Azure, Hetzner, …) with the official **Ubuntu Server 24.04 LTS** image.
- A local VM with [Multipass](https://canonical.com/multipass): `multipass launch 24.04 --name openshell-lab --cpus 2 --memory 8G --disk 30G`, then `multipass shell openshell-lab`.
- A bare-metal or desktop install from the [Ubuntu 24.04 ISO](https://ubuntu.com/download/server).

WSL 2 is only experimental for OpenShell. Avoid it for this course.

## 2. Update the system

```shell
sudo apt-get update
sudo apt-get -y full-upgrade
sudo apt-get install -y ca-certificates curl git jq bats python3-venv
sudo reboot   # only if the upgrade installed a new kernel
```

`bats` is the test runner the labs use to check your work. `python3-venv` is used in Lab 15.

## 3. Install Docker Engine from Docker's repository

Do **not** use the Docker snap. OpenShell is not compatible with it. Ubuntu's own `docker.io`
package can also lag behind 28.0, so install from Docker's apt repository
([official instructions](https://docs.docker.com/engine/install/ubuntu/)):

```shell
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
```

Let your user talk to Docker without `sudo`, then **log out and back in** so the group applies:

```shell
sudo usermod -aG docker "$USER"
```

Verify:

```shell
docker version --format '{{.Server.Version}}'   # 28.0 or newer
docker run --rm hello-world
```

## 4. Get the course

```shell
git clone https://github.com/omerfsen/openshell.git ~/openshell-training
cd ~/openshell-training
```

## 5. Check the host

```shell
scripts/check-host.sh
```

Expected output ends with `Host is ready for OpenShell.` Every `[FAIL]` line names the fix.

```text
OpenShell host check
  [ok]   OS: Ubuntu 24.04.4 LTS
  [ok]   architecture: x86_64
  [ok]   kernel: 6.8.0-147-generic (>= 6.2 for Landlock ABI 3)
  [ok]   Landlock LSM is enabled
  [ok]   cgroups v2
  [ok]   Docker Engine 29.9.1 (>= 28.0)
  ...
Host is ready for OpenShell.
```

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=00          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=00     # asciinema
labs/00-prepare-ubuntu/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/00-prepare-ubuntu/test.bats
```

## Troubleshooting

- `docker: permission denied while trying to connect to the Docker daemon socket`: you have
  not logged out and back in since `usermod -aG docker`.
- `Landlock LSM is not in /sys/kernel/security/lsm`: a custom kernel or boot parameter removed
  it. Stock Ubuntu 24.04 kernels enable it.

**Next:** [Lab 01 — Install OpenShell and meet the gateway](../01-install-and-gateway/README.md)
