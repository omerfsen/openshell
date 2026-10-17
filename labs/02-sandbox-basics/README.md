# Lab 02 — Sandbox basics

**Goal:** create, inspect, enter, run commands in, stop, start, and delete sandboxes.
**Time:** ~20 minutes. **Prerequisite:** [Lab 01](../01-install-and-gateway/README.md).

## Concepts

A **sandbox** is one isolated workload plus its supervisor. It has a **main process** (the
command after `--`, or a login shell if you give none). Its **phase** moves through
`Provisioning → Ready`, and `Stopped`, `Error`, or deleted afterwards.

The default image is `nvcr.io/nvidia/base/ubuntu:24.04`: a deliberately **minimal** Ubuntu
with no agent, no `curl`, and no `python3`. The workload always runs as a non-root user
(UID 1000 here) with no Linux capabilities.

## 1. Your first sandbox (interactive)

```shell
openshell sandbox create --name first --no-auto-providers
```

The first run pulls the default image. You land in a shell **inside** the sandbox:

```text
ubuntu@...:~$ id
uid=1000(ubuntu) gid=1000(ubuntu) groups=1000(ubuntu)
ubuntu@...:~$ pwd
/sandbox
```

Try a few things and note what fails:

```shell
touch ~/hello && echo "working dir is writable"
echo x > /etc/x          # Permission denied: /etc is read-only (Landlock)
ls /home                 # Permission denied: not in the policy at all
curl https://example.com # command not found: the base image is minimal
```

`--no-auto-providers` skips the prompt that offers to turn credentials found in your
environment into providers (Lab 08).

Leave the shell with `exit`. With the default `--restart-policy never`, the sandbox's main
process is gone once you exit.

## 2. Detached sandboxes and `exec`

For automation you want the sandbox to keep running without a terminal attached:

```shell
openshell sandbox create --name basics --no-auto-providers --detach
openshell sandbox list
```

```text
NAME    CREATED              PHASE
basics  2026-10-17 10:36:15  Ready
```

Run one-shot commands. The exit code comes back to your shell:

```shell
openshell sandbox exec -n basics -- id -un
openshell sandbox exec -n basics --no-login-shell -- cat /etc/os-release
openshell sandbox exec -n basics -- sh -c 'exit 3'; echo "exit code: $?"   # 3
echo "piped stdin" | openshell sandbox exec -n basics -- cat
openshell sandbox exec -n basics --env GREETING=merhaba -- sh -c 'echo $GREETING'
```

`--no-login-shell` skips `.profile` and similar files. Use it in scripts for predictable output.
Open an extra interactive shell any time with
`openshell sandbox exec -n basics --tty -- /bin/bash -l`.

## 3. Inspect

```shell
openshell sandbox get basics            # phase, conditions, restart info, and the policy
openshell sandbox get basics -o json | jq -r .phase
```

Look at the **Conditions** block: `Ready: True (DependenciesReady) - Supervisor session connected`
means the supervisor proved the boundary and connected back to the gateway. The agent is not
started before that.

## 4. Stop, start, delete

```shell
openshell sandbox stop basics     # keeps the workspace
openshell sandbox list            # PHASE: Stopped
openshell sandbox start basics
openshell sandbox exec -n basics -- sh -c 'ls ~'
openshell sandbox delete basics
```

Files in the working directory survive `stop`/`start` but not `delete`.

## 5. Throwaway sandboxes

`--no-keep` deletes the sandbox as soon as the main command exits. It's handy for one-off jobs:

```shell
openshell sandbox create --name once --no-auto-providers --no-keep --no-tty -- \
  sh -c 'echo hello from $(hostname) as $(id -un)'
openshell sandbox get once        # sandbox not found
```

## 6. Restart policies

`--restart-policy never|on-failure|always` controls what happens when the main process
exits. A long-running agent or server usually wants `on-failure`:

```shell
openshell sandbox create --name crashy --no-auto-providers --detach \
  --restart-policy on-failure -- sh -c 'sleep 5; exit 1'
sleep 20; openshell sandbox get crashy | grep -E 'Restart count|Last exit'
# Last exit code: 1
# Restart count: 3
openshell sandbox delete crashy
```

## 7. The terminal UI

`openshell term` opens an interactive dashboard of sandboxes, logs, and pending rules. Press
`?` inside it for keys.

## Exercises

1. Create a sandbox with `--cpu 1 --memory 512Mi` and confirm with `openshell sandbox get`.
2. What happens if you `exec` into a sandbox while it is `Stopped`?
3. Create a sandbox without `--name`. What name does OpenShell pick?

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=02          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=02     # asciinema
labs/02-sandbox-basics/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/02-sandbox-basics/test.bats
```

**Next:** [Lab 03 — Bring your own image](../03-custom-images/README.md)
