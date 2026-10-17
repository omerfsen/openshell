# Lab 05 — L7 REST rules: allow reads, block writes

**Goal:** go beyond "can reach host X". Let a program **read** an API but not **write** to it,
allow single methods and paths, carve out exceptions, and test rules safely in audit mode.
**Time:** ~25 minutes. **Prerequisite:** [Lab 04](../04-network-default-deny/README.md).

## Concepts

An endpoint without `protocol` is checked only at connect time (host, port, binary). Add
`protocol: rest` and the supervisor **terminates TLS and inspects each HTTP request**. (The
sandbox trusts a per-sandbox CA mounted at `/run/openshell-supervisor-ca`.) Then it checks the
method and path:

| Field | Meaning |
|---|---|
| `access: read-only` | Preset: `GET`, `HEAD`, `OPTIONS` |
| `access: read-write` | Preset: all methods |
| `rules: [{allow: {method, path}}]` | Explicit allow list (cannot be combined with `access`) |
| `deny_rules: [{method, path}]` | Exceptions; **a matching deny always wins**, wherever it appears |
| `enforcement: enforce` | Block violations with a `403` `policy_denied` JSON body |
| `enforcement: audit` | **Default.** Allow violations but log them |

Path globs: `*` matches within one segment, and `**` as a whole segment matches across segments.

CLI shorthand for an endpoint: `host:port:access:protocol:enforcement`, for example
`postman-echo.com:443:read-only:rest:enforce`.

## 1. Read-only access to an API

```shell
openshell sandbox create --name l7 --from openshell-training/tools:0.1.4 --no-auto-providers --detach
openshell policy update l7 --rule-name echo_api --binary /usr/bin/curl \
  --add-endpoint postman-echo.com:443:read-only:rest:enforce --wait

openshell sandbox exec -n l7 -- curl -s https://postman-echo.com/get; echo          # allowed
openshell sandbox exec -n l7 -- curl -s -X POST \
  https://postman-echo.com/post -d '{"title":"oops"}'; echo
```

The POST never reaches postman-echo. The supervisor answers it:

```json
{"error":"policy_denied","policy":"echo_api","rule":"POST /post",
 "detail":"POST /post not permitted by policy","layer":"l7",
 "protocol":"rest","method":"POST","path":"/post",
 "host":"postman-echo.com","port":443,"binary":"/usr/bin/curl", "rule_missing":{...}}
```

The machine-readable body is designed for agents: it says exactly what was missing, so an
agent can ask for it (Lab 10). The log line shows the L7 engine:

```text
HTTP:POST [MED] DENIED POST http://postman-echo.com:443/post [policy:echo_api engine:l7] ...
```

## 2. Allow one write, deny one path

Add a single extra permission to the existing rule. `--binary` must repeat the rule's
binaries, so a new permission can never reach a program you did not name:

```shell
openshell policy update l7 --rule-name echo_api --binary /usr/bin/curl \
  --add-allow 'postman-echo.com:443:POST:/post' --wait
```

OpenShell first expands the `read-only` preset into explicit `GET/HEAD/OPTIONS` rules, then
adds yours. Now carve out an exception. Deny `GET /headers` even though `GET` is
allowed:

```shell
openshell policy update l7 --rule-name echo_api --binary /usr/bin/curl \
  --add-deny 'postman-echo.com:443:GET:/headers' --wait

openshell sandbox exec -n l7 -- curl -s -o /dev/null -w '%{http_code}\n' https://postman-echo.com/get  # 200
openshell sandbox exec -n l7 -- curl -s -o /dev/null -w '%{http_code}\n' https://postman-echo.com/headers  # 403
openshell policy get l7 --base | sed -n '/network_policies/,$p'
```

## 3. Audit mode: try a rule before you enforce it

```shell
openshell policy update l7 --rule-name httpbin_audit --binary /usr/bin/curl \
  --add-endpoint httpbin.org:443:read-only:rest:audit --wait

openshell sandbox exec -n l7 -- curl -s -o /dev/null -w '%{http_code}\n' -X POST https://httpbin.org/post   # 200
openshell logs l7 --since 2m --source sandbox | grep 'HTTP:POST'
```

In audit mode the POST goes through and is recorded. When the log shows only the violations
you expect, switch the endpoint to `enforce`. Audit mode does **not** relax the safety checks.
Malformed requests and requests whose `Host` header names another host are still rejected.

## 4. The full YAML

Everything above, as a policy file you could apply with `openshell policy set` (Lab 07):

```yaml
network_policies:
  echo_api:
    endpoints:
      - host: postman-echo.com
        port: 443
        protocol: rest
        enforcement: enforce
        rules:
          - allow: { method: GET,     path: "**" }
          - allow: { method: HEAD,    path: "**" }
          - allow: { method: OPTIONS, path: "**" }
          - allow: { method: POST,    path: "/post" }
        deny_rules:
          - { method: GET, path: /headers }
    binaries:
      - path: /usr/bin/curl
```

## 5. Clean up

```shell
openshell sandbox delete l7
```

## Exercises

1. Use `access: read-only` against `pypi.org` and `files.pythonhosted.org` for
   `/usr/bin/python3.12` and run `python3 -m pip download --no-deps requests`. (Hint: the
   tools image has no `pip`. Add `python3-pip` to the Dockerfile first.)
2. Write a rule that allows `GET /repos/<you>/**` only. Does it allow `GET /repos/<you>`?
   Why not?

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=05          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=05     # asciinema
labs/05-l7-rest-rules/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/05-l7-rest-rules/test.bats
```

**Next:** [Lab 06 — Filesystem and process controls](../06-filesystem-and-process/README.md)
