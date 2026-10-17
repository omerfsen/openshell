#!/usr/bin/env bats
# Lab 10: mechanistic drafts, agent proposals over policy.local, auto approval.

load ../../tests/helpers

NAME=lab10-adv
AUTO=lab10-auto

setup_file() {
  ensure_tools_image
  create_sandbox "$NAME"
  create_sandbox "$AUTO" --approval-mode auto
}

teardown_file() {
  delete_sandbox "$NAME"
  delete_sandbox "$AUTO"
}

pending_chunk_for() {
  openshell rule get "$NAME" --status pending |
    awk -v rule="$1" '/Chunk:/ { id = $2 } /Rule:/ && $2 == rule { print id; exit }'
}

has_pending() {
  [ -n "$(pending_chunk_for "$1")" ]
}

@test "a denied connection becomes a pending draft" {
  http_code "$NAME" https://postman-echo.com/get >/dev/null
  EVENTUALLY_TRIES=10 EVENTUALLY_DELAY=2 eventually has_pending allow_postman_echo_com_443
}

@test "approving the draft opens the connection" {
  chunk="$(pending_chunk_for allow_postman_echo_com_443)"
  [ -n "$chunk" ]
  openshell rule approve "$NAME" --chunk-id "$chunk"
  EVENTUALLY_TRIES=10 EVENTUALLY_DELAY=2 eventually bash -c \
    "[ \"\$(openshell sandbox exec -n $NAME --no-login-shell -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 https://postman-echo.com/get)\" = 200 ]"
}

@test "policy.local is available once the advisor is enabled" {
  openshell settings set "$NAME" --key agent_policy_proposals_enabled --value true
  EVENTUALLY_TRIES=10 EVENTUALLY_DELAY=3 eventually bash -c \
    "openshell sandbox exec -n $NAME --no-login-shell -- curl -sf http://policy.local/v1/policy/current >/dev/null"
}

@test "the agent can submit a proposal" {
  run bash -c "openshell sandbox exec -n $NAME --no-login-shell -- curl -s -X POST \
    -H 'Content-Type: application/json' --data-binary @- http://policy.local/v1/proposals \
    < '$BATS_TEST_DIRNAME/proposal.json'"
  [[ "$output" == *'"accepted_chunks":1'* ]]
  EVENTUALLY_TRIES=5 EVENTUALLY_DELAY=2 eventually has_pending echo_status_read
}

@test "a rejection reason reaches the agent" {
  chunk="$(pending_chunk_for echo_status_read)"
  [ -n "$chunk" ]
  openshell rule reject "$NAME" --chunk-id "$chunk" --reason "lab10 rejection"
  run sx "$NAME" curl -s "http://policy.local/v1/proposals/$chunk"
  [[ "$output" == *'"status":"rejected"'* ]]
  [[ "$output" == *"lab10 rejection"* ]]
}

@test "auto mode approves a low-risk draft on its own" {
  http_code "$AUTO" https://example.com >/dev/null
  EVENTUALLY_TRIES=10 EVENTUALLY_DELAY=3 eventually bash -c \
    "[ \"\$(openshell sandbox exec -n $AUTO --no-login-shell -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 https://example.com)\" = 200 ]"
  run openshell rule get "$AUTO"
  [[ "$output" == *"approved"* ]]
}
