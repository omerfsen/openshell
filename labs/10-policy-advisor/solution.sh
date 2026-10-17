#!/usr/bin/env bash
# Lab 10 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 10 — The policy advisor"
run_quiet 'openshell sandbox delete adv auto'
run 'openshell sandbox create --name adv --from openshell-training/tools:0.1.4 --no-auto-providers --detach'
say "A denied connection becomes a draft proposal"
run 'openshell sandbox exec -n adv -- curl -sS --max-time 8 https://postman-echo.com/get'
run 'timeout 60 bash -c "until openshell rule get adv --status pending | grep -q Chunk:; do sleep 2; done"; openshell rule get adv --status pending'
run "CHUNK=\$(openshell rule get adv --status pending | awk '/Chunk:/ {print \$2; exit}'); openshell rule approve adv --chunk-id \$CHUNK"
run "sleep 6; openshell sandbox exec -n adv -- curl -s https://postman-echo.com/get | jq -c '{url}'"
say "Agent-authored proposals over policy.local"
run 'openshell settings set adv --key agent_policy_proposals_enabled --value true'
run "sleep 12; openshell sandbox exec -n adv -- curl -s 'http://policy.local/v1/denials?last=2' | jq ."
run 'cat labs/10-policy-advisor/proposal.json'
run "openshell sandbox exec -n adv -- curl -s -X POST -H 'Content-Type: application/json' --data-binary @- http://policy.local/v1/proposals < labs/10-policy-advisor/proposal.json | jq ."
run 'openshell rule get adv --status pending'
run "CHUNK=\$(openshell rule get adv --status pending | awk '/Chunk:/ {print \$2; exit}'); openshell rule reject adv --chunk-id \$CHUNK --reason 'Not needed for this task.' && openshell sandbox exec -n adv -- curl -s http://policy.local/v1/proposals/\$CHUNK | jq '{status, rejection_reason}'"
say "Automatic approval for low-risk drafts"
run 'openshell sandbox create --name auto --from openshell-training/tools:0.1.4 --no-auto-providers --approval-mode auto --detach'
run "openshell sandbox exec -n auto -- curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 https://example.com"
run "sleep 10; openshell sandbox exec -n auto -- curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 https://example.com"
run "openshell rule get auto | grep -E 'Rule:|Status:'"
run 'openshell sandbox delete adv auto'
