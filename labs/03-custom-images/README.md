# Lab 03 — Bring your own image

**Goal:** build the workload image the rest of the course uses, learn OpenShell's rules for
images, and ship a policy inside an image.
**Time:** ~15 minutes. **Prerequisite:** [Lab 02](../02-sandbox-basics/README.md).

## Concepts

OpenShell runs **any standard Linux OCI image**. It does not add tools to your image. It stages
its own static `openshell-sandbox` binary into the workload at runtime, so the image's libc
doesn't matter. What it enforces about images:

- `--from` takes an **image reference** (or a rootfs tar for the MicroVM driver). Since 0.1.0
  it no longer builds Dockerfiles: build with Docker first, then pass the tag.
- The workload never runs as **root**. Docker uses the image's `USER` if it is non-root, UID/GID
  1000 if the image has no `USER`, and **rejects** an image whose `USER` is root unless the
  policy sets a non-root `run_as_user`.
- An image may carry its own policy at **`/etc/openshell/policy.yaml`**. It is used only when
  no `--policy` or global policy applies. An invalid image policy blocks startup. OpenShell
  never silently falls back to the default.

## 1. Build the training tools image

[`images/tools/Dockerfile`](../../images/tools/Dockerfile) is Ubuntu 24.04 plus `curl`,
`wget`, `git`, `jq`, `python3`, `dig`, and `nc`. Those are the clients the network labs need.

```shell
docker build -t openshell-training/tools:0.1.4 images/tools
openshell sandbox create --name tools --from openshell-training/tools:0.1.4 --no-auto-providers --detach
openshell sandbox exec -n tools -- sh -c 'id; command -v curl python3 git'
```

The Docker gateway sees your local image store directly, so no registry is needed. For a
remote gateway, push the image to a registry that gateway can pull from.

Find the **real** paths of the clients. Network rules match the kernel-resolved executable,
not symlinks (you will need this in Lab 04):

```shell
openshell sandbox exec -n tools -- readlink -f /usr/bin/python3   # /usr/bin/python3.12
openshell sandbox exec -n tools -- readlink -f /usr/bin/nc        # /usr/bin/nc.openbsd
```

## 2. Root images are rejected

```shell
printf 'FROM ubuntu:24.04\nUSER root\n' | docker build -t openshell-training/rootimg:test -
openshell sandbox create --name rooty --from openshell-training/rootimg:test --no-auto-providers --detach
```

```text
Error:   × sandbox entered error phase while provisioning: IdentityResolutionFailed:
  │ descriptor error: workload identity must not contain UID or GID zero
```

```shell
openshell sandbox delete rooty
```

## 3. Ship a policy inside the image

[`images/baked-policy/`](../../images/baked-policy/) adds
[`policy.yaml`](../../images/baked-policy/policy.yaml) at `/etc/openshell/policy.yaml`. It
lets `curl` call exactly one endpoint, `GET https://postman-echo.com/get`:

```shell
docker build -t openshell-training/baked-policy:0.1.4 images/baked-policy
openshell sandbox create --name baked --from openshell-training/baked-policy:0.1.4 \
  --no-auto-providers --detach
openshell sandbox exec -n baked -- curl -s https://postman-echo.com/get; echo
openshell sandbox exec -n baked -- curl -s -o /dev/null -w '%{http_code}\n' https://postman-echo.com/headers   # 403
openshell policy get baked --base | sed -n '/^---/,$p' | head -20
```

`/get` reaches postman-echo, which echoes the request back as JSON. `/headers` on the same
host gets OpenShell's `403`, because the image policy only allows `GET /get`.

Policy precedence, highest first: **global policy → the sandbox's saved policy (`--policy` or
`OPENSHELL_SANDBOX_POLICY`) → image policy → built-in default.**

## 4. Clean up

```shell
openshell sandbox delete tools baked
```

## Exercises

1. Build an image `FROM python:3.12-slim` and find the real path of its interpreter. It is not
   `/usr/bin/python3.12`.
2. Put a typo in `images/baked-policy/policy.yaml` (for example `version: 9`), rebuild, and
   watch the sandbox stay in `Provisioning`. `openshell sandbox get <name> -o json` shows the
   `ConfigurationReady` condition with reason `ConfigurationInvalid`.

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=03          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=03     # asciinema
labs/03-custom-images/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/03-custom-images/test.bats
```

**Next:** [Lab 04 — Default-deny networking and binary-scoped rules](../04-network-default-deny/README.md)
