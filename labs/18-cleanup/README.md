# Lab 18 — Clean up, upgrade, uninstall, and where to go next

**Goal:** leave the machine tidy, know how to move to a newer OpenShell, and know how to
remove it completely.
**Time:** ~10 minutes.

## 1. Remove what the course created

```shell
scripts/cleanup.sh            # sandboxes, providers, profiles, templates, global overrides
scripts/cleanup.sh --images   # ...and the training images
openshell sandbox list
```

Deleting a sandbox stops its processes, removes its workspace, and revokes its credentials
and tokens. Copy out anything you want to keep first (Lab 09).

## 2. Upgrade OpenShell

OpenShell ships a stable release most weeks. Patch releases stay backward-compatible for
Stable interfaces, and security fixes go to the latest and previous minor lines (N-1). To
move to a newer release, rerun the installer with the new tag, then check:

```shell
curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | OPENSHELL_VERSION=v0.1.5 sh
openshell --version
openshell status
```

Upgrade the SDKs to the same version. Read the release notes before upgrading across a minor
version. This course is pinned to **0.1.4**: update [`VERSION`](../../VERSION) and rerun
`make test` to see what changed. Preview builds: `OPENSHELL_VERSION=pre` (needs `gh auth
login`) or `OPENSHELL_VERSION=dev`.

## 3. Uninstall (Debian/Ubuntu)

```shell
systemctl --user disable --now openshell-gateway
sudo apt remove openshell
rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/openshell"   # gateway database and TLS material
rm -rf ~/.config/openshell                                   # CLI registrations, gateway.toml
docker image ls | grep -E 'openshell|nvcr.io/nvidia/base' # remove runtime images if you like
```

## 4. Going further

These features need more than one VM, so the course explains them but has no lab for them:

| Topic | Where |
|---|---|
| **Kubernetes**: the Helm chart, NetworkPolicy-enforcing CNI, HA, ingress, OpenShift | [docs/kubernetes](https://github.com/NVIDIA/OpenShell/tree/v0.1.4/docs/kubernetes) |
| **MicroVM runtime**: libkrun/KVM sandboxes, rootfs tarballs | [Sandbox runtimes](https://github.com/NVIDIA/OpenShell/blob/v0.1.4/docs/how-it-works/sandboxes/runtimes.mdx) |
| **Podman** rootless runtime | same page |
| **Authentication**: OIDC login, edge auth, mTLS operators, workspaces | [Gateway authentication](https://github.com/NVIDIA/OpenShell/blob/v0.1.4/docs/how-it-works/gateways/authentication.mdx), [Workspaces](https://github.com/NVIDIA/OpenShell/blob/v0.1.4/docs/how-it-works/workspaces.mdx) |
| **Credential refresh**: OAuth2, Google service accounts, AWS STS, SPIFFE token exchange | [Provider profiles](https://github.com/NVIDIA/OpenShell/blob/v0.1.4/docs/how-it-works/providers/profiles.mdx), [`examples/spiffe-*`](https://github.com/NVIDIA/OpenShell/tree/v0.1.4/examples) |
| **Extensibility**: supervisor middleware (content guards), gateway interceptors, custom compute drivers | [docs/extensibility](https://github.com/NVIDIA/OpenShell/tree/v0.1.4/docs/extensibility) |
| **GPUs**: `--gpu` on Docker, VM, and Kubernetes | [Sandboxes overview](https://github.com/NVIDIA/OpenShell/blob/v0.1.4/docs/how-it-works/sandboxes/overview.mdx#gpu-resources) |
| **Agent skills** for your coding agent | `npx skills add NVIDIA/OpenShell` |
| **Upstream examples**: Jupyter, VS Code remote, Codex app server, multi-agent, private IP routing | [`examples/`](https://github.com/NVIDIA/OpenShell/tree/v0.1.4/examples) |

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=18          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=18     # asciinema
labs/18-cleanup/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/18-cleanup/test.bats
```

Congratulations, you have finished the course. 🎉
