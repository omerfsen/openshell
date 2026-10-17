# Lab 04 — Default-deny networking and binary-scoped rules

**Goal:** see that a sandbox can reach nothing by default, open one destination **for one
program only**, and read the audit trail.
**Time:** ~20 minutes. **Prerequisite:** [Lab 03](../03-custom-images/README.md).

## Concepts

The workload container has **no network device**. Its only path out is the authenticated
channel to the supervisor. When a program in the sandbox calls `connect()` or looks up a name,
the in-sandbox runtime intercepts it (seccomp user notification), records **which executable**
made the call (from trusted `/proc` data), and asks the supervisor. The supervisor checks
`network_policies`:

```yaml
network_policies:
  <rule-name>:
    endpoints: [ {host, port, ...} ]   # where
    binaries:  [ {path} ]              # who
```

A rule allows **every listed binary to reach every listed endpoint**, and nothing else.
Network rules **hot-reload**: no restart needed.

Things to remember:

- List the **real** executable path (`readlink -f`). Scripts show up as their interpreter
  (`pip` → `/usr/bin/python3.12`). Children of a listed binary inherit the rule.
- OpenShell hashes each binary the first time it connects and denies it later if the file
  changes.
- DNS answers inside the sandbox are **placeholder addresses** (198.18.0.0/15). The supervisor
  resolves the real address itself.
- Loopback, link-local, and the cloud metadata address `169.254.169.254` are **never**
  reachable through policy. Private ranges need an explicit `allowed_ips`. Loopback *inside*
  the sandbox (`127.0.0.1`) works normally.

## 1. Everything is denied

```shell
openshell sandbox create --name net --from openshell-training/tools:0.1.4 --no-auto-providers --detach
openshell sandbox exec -n net -- curl -sS --max-time 8 https://postman-echo.com/get
```

```text
curl: (7) Failed to connect to postman-echo.com port 443 after 13 ms: Couldn't connect to server
```

## 2. Read the deny log

```shell
openshell logs net --since 5m --source sandbox | grep -E 'NET:|HTTP:'
```

```text
[...] [sandbox] [OCSF ] [ocsf] NET:REFUSE [MED] DENIED postman-echo.com [reason:policy_dns_ineligible]
[...] [sandbox] [OCSF ] [ocsf] NET:OPEN [MED] DENIED /usr/bin/curl(0) -> postman-echo.com:443 [reason:transparent_tcp_policy_denied]
```

Every decision names the **binary**, the **destination**, and the **reason**. These are OCSF
(Open Cybersecurity Schema Framework) events you can ship to a SIEM (Lab 14). Do not filter
with `--level warn`: policy events are INFO records.

## 3. Allow one host for one binary

```shell
openshell policy update net \
  --rule-name echo_api \
  --binary /usr/bin/curl \
  --add-endpoint postman-echo.com:443 \
  --wait
```

```text
✓ Policy version 2 submitted (hash: ...)
✓ Policy version 2 loaded (active version: 2)
```

`--wait` blocks until the sandbox has **loaded** the revision. Now:

```shell
openshell sandbox exec -n net -- curl -s https://postman-echo.com/get; echo     # works
openshell sandbox exec -n net -- python3 -c \
  'import urllib.request; print(urllib.request.urlopen("https://postman-echo.com/get").read())'
# urllib.error.URLError: <urlopen error [Errno 13] Permission denied>
```

Same host, same sandbox, but `python3.12` is not in the rule, so it is denied. The log says so:

```text
NET:OPEN [MED] DENIED /usr/bin/python3.12(0) -> postman-echo.com:443 [reason:transparent_tcp_policy_denied]
NET:OPEN [INFO] ALLOWED /usr/bin/curl(0) -> postman-echo.com:443 [policy:echo_api engine:opa]
```

This is the core idea of OpenShell: **network access is granted to a program, not to the
sandbox.** An agent's tool may download from a registry while a stray script may not.

## 4. Things policy can never open

```shell
openshell policy update net --rule-name meta --binary /usr/bin/curl \
  --add-endpoint 169.254.169.254:80 --wait
```

```text
... link-local/unspecified); the proxy will deny traffic to this destination regardless of policy
```

Loopback inside the sandbox still works. Agents can run local dev servers:

```shell
openshell sandbox exec -n net -- sh -c \
  'python3 -m http.server 9000 --bind 127.0.0.1 >/dev/null 2>&1 & sleep 1; curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:9000/'
# 200
```

## 5. Remove access again

```shell
openshell policy update net --remove-rule echo_api --wait
openshell sandbox exec -n net -- curl -sS --max-time 8 https://postman-echo.com/get   # denied again
openshell policy list net   # every change is a numbered revision
```

## 6. Clean up

```shell
openshell sandbox delete net
```

## Exercises

1. Allow `wget` (find its real path first) to reach `example.com:443`, and check that `curl`
   still can't.
2. Use `--dry-run` instead of `--wait` and compare the output.
3. A rule with `binaries: []` matches nothing. Why is that a safe default?

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=04          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=04     # asciinema
labs/04-network-default-deny/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/04-network-default-deny/test.bats
```

**Next:** [Lab 05 — L7 REST rules: allow reads, block writes](../05-l7-rest-rules/README.md)
