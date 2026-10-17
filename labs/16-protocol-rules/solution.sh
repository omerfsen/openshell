#!/usr/bin/env bash
# Lab 16 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 16 — Protocol-aware rules"
run_quiet 'openshell sandbox delete proto'
run 'openshell sandbox create --name proto --from openshell-training/tools:0.1.4 --no-auto-providers --detach'
run 'openshell policy set proto --policy labs/16-protocol-rules/policy.yaml --wait'
say "GraphQL: queries yes, mutations no"
run "openshell sandbox exec -n proto -- curl -s -X POST https://countries.trevorblades.com/graphql -H 'Content-Type: application/json' -d '{\"query\":\"query { country(code:\\\"TR\\\") { name capital } }\"}'; echo"
run "openshell sandbox exec -n proto -- curl -s -X POST https://countries.trevorblades.com/graphql -H 'Content-Type: application/json' -d '{\"query\":\"mutation { addCountry(code:\\\"XX\\\") { code } }\"}' | jq -c '{error, detail}'"
say "MCP: tools allowed by name"
run "openshell sandbox exec -n proto -- curl -s -X POST https://mcp.deepwiki.com/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -H 'MCP-Protocol-Version: 2025-11-25' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"read_wiki_structure\",\"arguments\":{\"repoName\":\"NVIDIA/OpenShell\"}}}' | sed -n 2p | cut -c1-240"
run "openshell sandbox exec -n proto -- curl -s -X POST https://mcp.deepwiki.com/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -H 'MCP-Protocol-Version: 2025-11-25' -d '{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"ask_wiki_question\",\"arguments\":{\"repoName\":\"NVIDIA/OpenShell\",\"question\":\"hi\"}}}' | jq -c '{error, detail}'"
say "WebSocket: upgrade allowed on /raw, denied on /socketio"
run "for p in raw socketio; do openshell sandbox exec -n proto -- curl -s -o /dev/null -w \"\$p %{http_code}\n\" --http1.1 --max-time 5 -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' https://ws.postman-echo.com/\$p; done"
say "Native TCP"
run "openshell sandbox exec -n proto -- sh -c 'echo hello-tcp | timeout 8 nc -q 2 tcpbin.com 4242'"
run 'openshell sandbox delete proto'
