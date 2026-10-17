# Lab 06 — Filesystem and process controls

**Goal:** confine what an agent can read and write with Landlock, pin its process identity,
and learn which parts of a policy are **locked at startup**.
**Time:** ~20 minutes. **Prerequisite:** [Lab 05](../05-l7-rest-rules/README.md).

## Concepts

A policy file has up to five sections, and they take effect at different times:

| Section | Controls | Enforced by | Changeable on a running sandbox? |
|---|---|---|---|
| `filesystem_policy` | Paths that are read-only or read-write | **Landlock** LSM in the kernel | No. Recreate the sandbox. |
| `landlock` | `best_effort` or `hard_requirement` | Sandbox runtime | No |
| `process` | `run_as_user` / `run_as_group` (numeric or `sandbox`, never root) | Docker/Podman at creation | No |
| `network_policies` | Labs 04–05 | Supervisor | **Yes, hot reload** |
| `network_middlewares` | Extra inspection of allowed traffic | Supervisor | Yes |

Anything not listed in `filesystem_policy` is **invisible**: not even listable. A private
`/.openshell` directory (the runtime's own channel and bootstrap files) is protected by a
mandatory Landlock baseline that no policy can open. That is why OpenShell needs Landlock
ABI 3 (Linux 6.2+).

When a policy has at least one network rule, OpenShell automatically adds the baseline paths
networked programs need (`/usr`, `/lib`, `/etc`, `/proc`, … read-only and `/tmp` read-write)
if they are missing. It never widens a path you listed.

## 1. Create a sandbox from a policy file

[`policy.yaml`](policy.yaml) in this folder grants read-only `/usr /lib /etc /proc
/dev/urandom`, read-write `/tmp`, `/dev/null`, and the working directory, demands Landlock
(`hard_requirement`), and pins UID/GID 1000. It has no network rules.

```shell
openshell sandbox create --name fs --from openshell-training/tools:0.1.4 \
  --policy labs/06-filesystem-and-process/policy.yaml --no-auto-providers --detach
```

## 2. Probe the boundary

```shell
openshell sandbox exec -n fs -- sh -c '
  id
  echo a > ~/w      && echo "home: writable"
  echo b > /tmp/w   && echo "/tmp: writable"
  echo c > /etc/x   || echo "/etc: read-only"
  ls /var/log       || echo "/var/log: not in policy"
  ls /opt           || echo "/opt: not in policy"
  cat /etc/shadow   || echo "/etc/shadow: still protected by Unix permissions"
  ls /.openshell    || echo "/.openshell: protected baseline"'
```

```text
uid=1000(ubuntu) gid=1000(ubuntu) ...
home: writable
/tmp: writable
sh: 1: cannot create /etc/x: Permission denied
/etc: read-only
ls: cannot open directory '/var/log': Permission denied
...
ls: cannot open directory '/.openshell': Permission denied
```

Landlock is enforced by the kernel for the whole process tree, so a child process, a shell
escape, or a compiled binary all hit the same wall.

## 3. Startup sections are locked

Try to widen the filesystem while the sandbox runs:

```shell
sed 's#    - /dev/urandom#    - /dev/urandom\n    - /opt#' \
  labs/06-filesystem-and-process/policy.yaml > /tmp/fs-add.yaml
openshell policy set fs --policy /tmp/fs-add.yaml --wait     # accepted and saved...
openshell sandbox exec -n fs -- ls /opt                       # ...but still Permission denied
```

Adding a path is saved as a new revision, but the running workload keeps its original
Landlock ruleset. It applies only after you recreate the sandbox. Removing a path or changing
Landlock on a live sandbox is **rejected** outright:

```shell
grep -v /dev/urandom labs/06-filesystem-and-process/policy.yaml > /tmp/fs-remove.yaml
openshell policy set fs --policy /tmp/fs-remove.yaml --wait
# × ... filesystem read_only path '/dev/urandom' cannot be removed on a live sandbox

sed 's/hard_requirement/best_effort/' labs/06-filesystem-and-process/policy.yaml > /tmp/fs-ll.yaml
openshell policy set fs --policy /tmp/fs-ll.yaml --wait
# × ... landlock policy cannot be changed on a live sandbox (applied at startup)
```

To change any of these, recreate:

```shell
openshell sandbox delete fs
openshell sandbox create --name fs --from openshell-training/tools:0.1.4 \
  --policy /tmp/fs-add.yaml --no-auto-providers --detach
openshell sandbox exec -n fs -- ls /opt && echo "/opt is visible now"
```

## 4. Process identity

`run_as_user` and `run_as_group` accept a numeric ID (1 – 4294967294) or `sandbox`. Root (`0`)
is rejected by the schema, and a root image is rejected at creation (Lab 03). Names like
`ubuntu` are **not** accepted:

```text
... run_as_user ... expected 'sandbox' or a numeric id in [1, 4294967294], got 'ubuntu'
```

## 5. Clean up

```shell
openshell sandbox delete fs
```

## Exercises

1. Remove `include_workdir: true`. Where can the agent write now?
2. Make `/tmp` read-only and run `python3 -c 'import tempfile; tempfile.mkstemp()'`.
3. Set `run_as_user: "1500"` and check `id` inside. Which user name does it show, and why?

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=06          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=06     # asciinema
labs/06-filesystem-and-process/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/06-filesystem-and-process/test.bats
```

**Next:** [Lab 07 — Policy lifecycle: files, revisions, rollback](../07-policy-lifecycle/README.md)
