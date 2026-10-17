# Lab 14 — Observability: logs and OCSF audit events

**Goal:** answer "what did the agent try to do?" from the command line and in a form your
SIEM can ingest.
**Time:** ~20 minutes. **Prerequisite:** [Lab 13](../13-templates-labels-settings/README.md).

## Concepts

Every policy decision, process launch, SSH session, and configuration change produces an
event in the **OCSF** (Open Cybersecurity Schema Framework) format. You see them three ways:

| View | How | For |
|---|---|---|
| Shorthand lines | `openshell logs <sandbox>` | Humans and agents, in real time |
| Full OCSF JSON | `ocsf_json_enabled=true`, then the supervisor container's stderr | SIEM / log pipelines |
| Gateway JSONL file | `[openshell.gateway.ocsf_log]` in `gateway.toml` | Gateway-wide audit events |

Shorthand anatomy:

```text
[1792233453.809] [sandbox] [OCSF ] [ocsf] NET:OPEN [MED] DENIED /usr/bin/curl(0) -> postman-echo.com:443 [reason:transparent_tcp_policy_denied]
 └ timestamp      └ source         └ class:activity └ severity └ decision └ binary(pid) -> destination   └ why
```

Policy events are **INFO** records regardless of severity, so never filter them away with
`--level warn`.

## 1. Generate some activity

```shell
openshell sandbox create --name obs --from openshell-training/tools:0.1.4 --no-auto-providers --detach
openshell policy update obs --rule-name echo_api --binary /usr/bin/curl \
  --add-endpoint postman-echo.com:443:read-only:rest:enforce --wait
openshell sandbox exec -n obs -- curl -s -o /dev/null https://postman-echo.com/get              # allowed
openshell sandbox exec -n obs -- curl -s -o /dev/null -X POST https://postman-echo.com/get      # L7 denied
openshell sandbox exec -n obs -- curl -s -o /dev/null --max-time 5 https://example.com        # L4 denied
```

## 2. Read the logs

```shell
openshell logs obs --since 5m --source sandbox | grep -E 'NET:|HTTP:'
openshell logs obs -n 20                      # last 20 lines from all sources
openshell logs obs --tail                     # follow live (Ctrl-C to stop)
openshell logs obs --since 5m --source gateway
```

```text
NET:OPEN [INFO] ALLOWED /usr/bin/curl(0) -> postman-echo.com:443 [policy:echo_api engine:opa]
HTTP:POST [MED] DENIED POST http://postman-echo.com:443/get [policy:echo_api engine:l7] [reason:L7_REQUEST deny POST postman-echo.com:443/get ...]
NET:OPEN [MED] DENIED /usr/bin/curl(0) -> example.com:443 [reason:transparent_tcp_policy_denied]
```

`engine:opa` is the connection-level decision, and `engine:l7` is request inspection. A quick
denial report:

```shell
openshell logs obs --since 1h --source sandbox | grep DENIED | grep -oE '(NET|HTTP):[A-Z]+ .*' | sort | uniq -c
```

## 3. Full OCSF JSON for a SIEM

```shell
openshell settings set obs --key ocsf_json_enabled --value true
sleep 12                                       # next settings poll
openshell sandbox exec -n obs -- curl -s -o /dev/null --max-time 5 https://example.com
```

The JSON goes to the **supervisor container's** stderr. Docker names it
`openshell-<workspace>--<sandbox>-<id>-supervisor`:

```shell
SUP=$(docker ps --format '{{.Names}}' | grep -- '--obs-.*-supervisor$')
docker logs --since 1m "$SUP" 2>&1 | grep ' OCSF-JSON ' | head -1 | sed 's/.* OCSF-JSON //' | jq .
```

```json
{
  "class_uid": 4001,
  "class_name": "Network Activity",
  "activity_name": "Open",
  "severity": "Medium",
  "status": "Failure",
  "action": "Denied",
  ...
}
```

Point Vector, Fluent Bit, or the Splunk/Elastic Docker log driver at those containers and
keep only lines with the `OCSF-JSON` token, which avoids ingesting the shorthand copy too.
Collection is best-effort, so don't treat it as a guaranteed complete audit trail.

## 4. Gateway-side observability

```shell
journalctl --user -u openshell-gateway --since '10 min ago'
openshell doctor check
openshell gateway info
```

**Prometheus metrics** (optional, not covered by the tests): add `OPENSHELL_METRICS_PORT=9090`
to `~/.config/openshell/gateway.env`, run `systemctl --user restart openshell-gateway`, then
`curl -s http://127.0.0.1:9090/metrics | head`. The endpoint is plain HTTP without
authentication, so keep it on loopback or a monitoring-only network. The gateway can also
export OTLP traces (`[openshell.gateway.otlp]`).

## 5. Clean up

```shell
openshell sandbox delete obs
```

## Exercises

1. Write a `jq` filter that prints only denied HTTP requests (`class_name` "HTTP Activity") from the
   supervisor log.
2. Set `ocsf_json_enabled` globally (`--global --yes`) and check a second sandbox.

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=14          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=14     # asciinema
labs/14-observability/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/14-observability/test.bats
```

**Next:** [Lab 15 — The Python SDK](../15-python-sdk/README.md)
