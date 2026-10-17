#!/usr/bin/env bats
# Lab 16: GraphQL, MCP, WebSocket, and TCP rules against public services.

load ../../tests/helpers

NAME=lab16-proto
MCP_HEADERS=(-H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -H 'MCP-Protocol-Version: 2025-11-25')

setup_file() {
  ensure_tools_image
  create_sandbox "$NAME"
  openshell policy set "$NAME" --policy "$BATS_TEST_DIRNAME/policy.yaml" --wait >/dev/null
}

teardown_file() {
  delete_sandbox "$NAME"
}

graphql() {
  sx "$NAME" curl -s --max-time 15 -X POST https://countries.trevorblades.com/graphql \
    -H 'Content-Type: application/json' -d "$1"
}

mcp_call() {
  sx "$NAME" curl -s --max-time 20 -X POST https://mcp.deepwiki.com/mcp "${MCP_HEADERS[@]}" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$1\",\"arguments\":{\"repoName\":\"NVIDIA/OpenShell\",\"question\":\"hi\"}}}"
}

ws_upgrade() {
  sx "$NAME" curl -s -o /dev/null -w '%{http_code}' --http1.1 --max-time 5 \
    -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' \
    -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' "https://ws.postman-echo.com/$1" || true
}

@test "the protocol policy loads" {
  run openshell policy list "$NAME"
  [[ "$(sed -n 2p <<<"$output")" == *Loaded* ]]
}

@test "GraphQL queries are allowed" {
  run graphql '{"query":"query { country(code:\"TR\") { capital } }"}'
  [[ "$output" == *'"capital":"Ankara"'* ]]
}

@test "GraphQL mutations are denied" {
  run graphql '{"query":"mutation { addCountry(code:\"XX\") { code } }"}'
  [[ "$output" == *'"error":"policy_denied"'* ]]
  [[ "$output" == *"GraphQL operation blocked"* ]]
}

@test "MCP allowed tool reaches the server" {
  run mcp_call read_wiki_structure
  [[ "$output" == *'"result"'* ]]
}

@test "MCP tool in deny_rules is blocked" {
  run mcp_call ask_wiki_question
  [[ "$output" == *"blocked by a deny rule"* ]]
}

@test "MCP tool without an allow rule is blocked" {
  run mcp_call read_wiki_contents
  [[ "$output" == *"no matching allow rule"* ]]
}

@test "WebSocket upgrade is allowed on /raw" {
  run ws_upgrade raw
  [ "$output" = "101" ]
}

@test "WebSocket upgrade is denied on /socketio" {
  run ws_upgrade socketio
  [ "$output" = "403" ]
}

@test "native TCP reaches the allowed port" {
  run sx "$NAME" sh -c 'echo hello-tcp | timeout 8 nc -q 2 tcpbin.com 4242'
  [ "$output" = "hello-tcp" ]
}

@test "native TCP to another port is denied" {
  run sx "$NAME" sh -c 'echo x | timeout 5 nc -q 1 tcpbin.com 4243'
  [ "$status" -ne 0 ]
}

@test "the prover reports protocol rules as unsupported" {
  openshell sandbox get "$NAME" --policy-only >"$BATS_TEST_TMPDIR/proto.yaml"
  run openshell-prover check "$BATS_TEST_TMPDIR/proto.yaml" --boundary "$REPO_ROOT/labs/11-policy-prover/boundary.yaml"
  [ "$status" -eq 3 ]
  [[ "$output" == *"result: unsupported"* ]]
}
