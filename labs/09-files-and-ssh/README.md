# Lab 09 — Files, SSH, and editors

**Goal:** move code into and results out of a sandbox, attach to it over SSH, and open it in
VS Code or Cursor.
**Time:** ~15 minutes. **Prerequisite:** [Lab 08](../08-providers-and-credentials/README.md).

## Concepts

Every sandbox runs an SSH server inside the supervisor. There is no open port: the CLI tunnels
SSH through the gateway with `openshell ssh-proxy`, authenticated by your gateway credentials.
`upload`, `download`, `connect`, and editor integration all use that tunnel, so they need a
working OpenSSH client on your host.

- **Uploads respect `.gitignore`** when the source is inside a Git work tree, so `build/`,
  `node_modules/`, and logs are not copied. `--no-git-ignore` turns that off.
- **Downloads are confined to the sandbox working directory.** `/etc/passwd` or
  `../etc/passwd` are refused before any data moves.
- Each sandbox has its own SSH host key. The private key lives only in the supervisor, and
  the workload can't read it.

> **Prerequisite check:** OpenSSH refuses to run if `~/.ssh/config` has the wrong owner or
> permissions (`Bad owner or permissions on ~/.ssh/config`). Fix it with
> `chmod 600 ~/.ssh/config`.

## 1. Upload a project

[`sample-project/`](sample-project/) has `src/app.py`, a `README.md`, and a `.gitignore` that
excludes `build/` and `*.log`. Create some ignored files, then upload:

```shell
mkdir -p labs/09-files-and-ssh/sample-project/build
echo junk > labs/09-files-and-ssh/sample-project/build/artifact.bin
echo junk > labs/09-files-and-ssh/sample-project/debug.log

openshell sandbox create --name files --from openshell-training/tools:0.1.4 --no-auto-providers --detach
openshell sandbox upload files labs/09-files-and-ssh/sample-project
openshell sandbox exec -n files -- find sample-project -type f
```

```text
sample-project/README.md
sample-project/.gitignore
sample-project/src/app.py
```

`build/artifact.bin` and `debug.log` stayed on your machine. Run the uploaded code:

```shell
openshell sandbox exec -n files -- python3 sample-project/src/app.py
```

You can also upload at creation time:
`openshell sandbox create ... --upload ./src:/home/ubuntu/src --upload ./config:/home/ubuntu/config`.
Every `--upload` is checked before the sandbox is provisioned.

## 2. Download results

```shell
openshell sandbox exec -n files -- sh -c 'mkdir -p out && date > out/report.txt'
openshell sandbox download files out ./lab09-out
cat lab09-out/report.txt

openshell sandbox download files /etc/passwd ./passwd   # refused: outside the working directory
```

## 3. SSH and attach

```shell
openshell sandbox connect files          # attach to the main process
# detach with Ctrl-D, or Ctrl-P then Ctrl-Q

openshell sandbox ssh-config files       # a Host block for any SSH client
openshell sandbox ssh-config files >> ~/.ssh/config
ssh openshell-files.default 'uname -a'
```

The generated block uses `ProxyCommand openshell ssh-proxy ...`, so plain `ssh`, `scp`,
`rsync`, and Ansible all work against the sandbox without exposing a port.

`connect` reattaches automatically if your laptop sleeps or the network drops: it retries for
up to 60 seconds and replays up to 1 MiB of recent output.

## 4. Editors

```shell
openshell sandbox create --name editor --from openshell-training/tools:0.1.4 \
  --no-auto-providers --editor vscode
openshell sandbox connect files --editor cursor
```

`--editor` keeps the sandbox alive and writes an OpenShell-managed SSH include file instead
of editing your main `~/.ssh/config`. The editor's remote server runs **inside** the
sandbox, under the same policy as everything else, so its downloads need network rules too.

## 5. Clean up

```shell
openshell sandbox delete files
rm -rf lab09-out labs/09-files-and-ssh/sample-project/build labs/09-files-and-ssh/sample-project/debug.log
```

## Exercises

1. Upload with `--no-git-ignore` and list what arrives.
2. Upload a single file to a new path: `openshell sandbox upload files ./README.md notes/readme.md --no-git-ignore`.

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=09          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=09     # asciinema
labs/09-files-and-ssh/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/09-files-and-ssh/test.bats
```

Tests that need SSH are **skipped** with a clear message when `~/.ssh/config` is rejected by
OpenSSH.

**Next:** [Lab 10 — The policy advisor](../10-policy-advisor/README.md)
