# Lab 16 — Protocol-aware rules: GraphQL, MCP, WebSocket, TCP

**Goal:** control traffic by **what it means**, not just where it goes: GraphQL operations,
MCP tool calls, WebSocket upgrades, and raw TCP for non-HTTP clients.
**Time:** ~25 minutes. **Prerequisite:** [Lab 07](../07-policy-lifecycle/README.md).

## Concepts

A REST rule sees every GraphQL request as `POST /graphql` and every MCP call as
`POST /mcp`, so it can't tell a query from a mutation, or `read_status` from
`delete_everything`. The `protocol` field selects a parser:

| `protocol` | What OpenShell checks | Rule fields |
|---|---|---|
| `rest` | Method, path, query | `method`, `path`, `query` |
| `graphql` | Operation type, name, top-level fields | `operation_type`, `operation_name`, `fields` |
| `mcp` | MCP method and **tool name** | `method`, `tool` |
| `websocket` | The upgrade request and every client **text** message | `method: GET` / `WEBSOCKET_TEXT`, `path` |
| `json-rpc` | JSON-RPC method | `method` |
| `tcp` | Nothing beyond host, port, binary | none |

These need a complete policy file (`openshell policy set`), because `policy update` only
builds REST and plain endpoints. [`policy.yaml`](policy.yaml) has one rule per protocol, all
for `curl` (and `nc` for TCP), against public test services:

| Rule | Service | Allowed | Denied |
|---|---|---|---|
| `countries_graphql` | countries.trevorblades.com | `query` operations | mutations |
| `deepwiki_mcp` | mcp.deepwiki.com (public MCP server) | `initialize`, `tools/list`, `tools/call read_wiki_structure` | `ask_wiki_question` (deny rule), any other tool |
| `ws_echo` | ws.postman-echo.com | upgrade + text on `/raw` | `/socketio` |
| `tcp_echo` | tcpbin.com:4242 | `nc` on port 4242 | any other port or binary |

## 1. Apply the policy

```shell
openshell sandbox create --name proto --from openshell-training/tools:0.1.4 --no-auto-providers --detach
openshell policy set proto --policy labs/16-protocol-rules/policy.yaml --wait
```

## 2. GraphQL: queries yes, mutations no

```shell
openshell sandbox exec -n proto -- curl -s -X POST https://countries.trevorblades.com/graphql \
  -H 'Content-Type: application/json' \
  -d '{"query":"query { country(code:\"TR\") { name capital } }"}'
# {"data":{"country":{"capital":"Ankara","name":"Turkey"}}}

openshell sandbox exec -n proto -- curl -s -X POST https://countries.trevorblades.com/graphql \
  -H 'Content-Type: application/json' \
  -d '{"query":"mutation { addCountry(code:\"XX\") { code } }"}'
# {"error":"policy_denied","policy":"countries_graphql",...,"detail":"GraphQL operation blocked by endpoint policy",...}
```

In a batched request, one disallowed operation denies the whole batch.

## 3. MCP: allow tools by name

The MCP rules apply to each JSON-RPC request in a Streamable HTTP session:

```shell
H='-H Content-Type:application/json -H Accept:application/json,text/event-stream -H MCP-Protocol-Version:2025-11-25'
openshell sandbox exec -n proto -- curl -s -X POST https://mcp.deepwiki.com/mcp $H \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"read_wiki_structure","arguments":{"repoName":"NVIDIA/OpenShell"}}}' | sed -n 2p | cut -c1-300
# data: {"jsonrpc":"2.0","id":1,"result":{"content":[{"type":"text","text":"Available pages for NVIDIA/OpenShell: ...

openshell sandbox exec -n proto -- curl -s -X POST https://mcp.deepwiki.com/mcp $H \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"ask_wiki_question","arguments":{"repoName":"NVIDIA/OpenShell","question":"hi"}}}'; echo
# {"error":"policy_denied",...,"detail":"MCP request blocked by a deny rule; ask the policy owner to review deny_rules and tool selectors",...}

openshell sandbox exec -n proto -- curl -s -X POST https://mcp.deepwiki.com/mcp $H \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"read_wiki_contents","arguments":{"repoName":"NVIDIA/OpenShell"}}}'; echo
# {"error":"policy_denied",...,"detail":"MCP tool call has no matching allow rule; ..."}
```

This is how you give an agent an MCP server while keeping its dangerous tools out of reach.
Tool **arguments** are not matched, so an allowed tool accepts any arguments the server
does. Without `mcp.versions`, only the `2025-11-25` protocol revision is allowed.

## 4. WebSocket: control the upgrade and the messages

`curl` in the tools image has no WebSocket client, but the policy check happens on the
HTTP/1.1 upgrade request, which curl can send:

```shell
for path in raw socketio; do
  openshell sandbox exec -n proto -- curl -s -o /dev/null -w "$path %{http_code}\n" --http1.1 --max-time 5 \
    -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' \
    -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' https://ws.postman-echo.com/$path
done
# raw 101          (Switching Protocols: upgrade allowed)
# socketio 403     (denied by policy)
```

After the upgrade, every client **text** message is checked against `WEBSOCKET_TEXT` rules.
Binary frames and server messages are not inspected. If the endpoint carries provider
credentials, a binary frame closes the connection (code 1008) unless you set
`allow_uninspected_credentials: true`. A policy reload closes open WebSockets.

## 5. Native TCP

```shell
openshell sandbox exec -n proto -- sh -c 'echo hello-tcp | timeout 8 nc -q 2 tcpbin.com 4242'   # hello-tcp
openshell sandbox exec -n proto -- sh -c 'echo x | timeout 5 nc -q 1 tcpbin.com 4243; echo rc=$?' # rc=1 (port not allowed)
```

The rule names `/usr/bin/nc.openbsd`, the real path behind `/usr/bin/nc`. With `tcp` you get
no request-level control, so prefer an inspected protocol whenever the client speaks one. For
protocols where the server talks first (SMTP, MySQL) or the client must do its own TLS, add
`tls: skip`.

## 6. The prover's view

```shell
openshell sandbox get proto --policy-only > /tmp/proto.yaml
openshell-prover check /tmp/proto.yaml --boundary labs/11-policy-prover/boundary.yaml
# result: unsupported ... uses protocol 'graphql'; only L4 TCP and REST are modeled
```

The prover refuses to guess about protocols it doesn't model. Review these rules by hand.

## 7. Clean up

```shell
openshell sandbox delete proto
```

## Exercises

1. Allow the `addCountry` mutation only: `operation_type: mutation`, `fields: [addCountry]`.
2. Add `{ method: tools/list }` to a deny rule and watch an MCP client fail to discover tools.

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=16          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=16     # asciinema
labs/16-protocol-rules/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/16-protocol-rules/test.bats
```

**Next:** [Lab 17 — Run a real AI agent](../17-run-an-agent/README.md)
