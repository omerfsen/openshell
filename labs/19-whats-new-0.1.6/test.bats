#!/usr/bin/env bats
# Lab 19 (bonus): the host runs 0.1.6 and its new features behave as the lab says.

load ../../tests/helpers

setup_file() {
  ensure_tools_image
  export LAB19_TOKEN=demo-value-19
  create_sandbox lab19-new --env-from LAB19_TOKEN --env-from API_TOKEN=LAB19_TOKEN \
    --annotation team=platform --annotation 'note=has spaces / and ='
}

teardown_file() {
  delete_sandbox lab19-new
  delete_sandbox lab19-bad
}

@test "CLI and gateway are 0.1.6 and still use mTLS" {
  run openshell --version
  [[ "$output" == *"0.1.6"* ]]
  run openshell status
  [[ "$output" == *"Status: Connected"* ]]
  [[ "$output" == *"mTLS"* ]]
  [[ "$output" == *"Version: 0.1.6"* ]]
}

@test "a request with no credential is refused as UNAUTHENTICATED" {
  run curl -sk --http2 -i -X POST -H 'content-type: application/grpc' -H 'te: trailers' \
    --data-binary @/dev/null https://127.0.0.1:17670/openshell.v1.OpenShell/ListSandboxes
  [[ "$output" == *"grpc-status: 16"* ]]
}

@test "the refusal is written as an OCSF AUTH:LOGON DENIED event" {
  curl -sk --http2 -o /dev/null -X POST -H 'content-type: application/grpc' -H 'te: trailers' \
    --data-binary @/dev/null https://127.0.0.1:17670/openshell.v1.OpenShell/ListSandboxes
  denied() {
    journalctl --user -u openshell-gateway --since -2min --no-pager |
      grep -q 'AUTH:LOGON.*DENIED.*reason:missing_credential'
  }
  EVENTUALLY_TRIES=5 EVENTUALLY_DELAY=1 eventually denied
}

@test "--env-from copies variables from the CLI environment" {
  run sx lab19-new sh -c 'echo "$LAB19_TOKEN $API_TOKEN"'
  [[ "$output" == *"demo-value-19 demo-value-19"* ]]
}

@test "--env-from refuses an unset source variable" {
  run openshell sandbox create --name lab19-bad --from "$TOOLS_IMAGE" \
    --no-auto-providers --detach --env-from NOPE_NOT_SET_LAB19
  [ "$status" -ne 0 ]
  [[ "$output" == *"is not set"* ]]
}

@test "annotations are stored, including spaces, slashes and =" {
  run openshell sandbox get lab19-new
  [[ "$output" == *"team: platform"* ]]
  [[ "$output" == *"note: has spaces / and ="* ]]
}

@test "the internal.openshell.ai/ prefix is reserved" {
  run openshell sandbox create --name lab19-bad --from "$TOOLS_IMAGE" \
    --no-auto-providers --detach --annotation internal.openshell.ai/x=1
  [ "$status" -ne 0 ]
  [[ "$output" == *"reserved"* ]]
}

@test "suspend is refused by the Docker driver and the sandbox keeps running" {
  run openshell sandbox suspend lab19-new
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not support sandbox suspend"* ]]
  run sx lab19-new true
  [ "$status" -eq 0 ]
}

@test "the push config preflights and sets config_delivery_mode" {
  run openshell-gateway config preflight --path "$BATS_TEST_DIRNAME/gateway-push.toml"
  [ "$status" -eq 0 ]
  grep -q '^config_delivery_mode *= *"push"' "$BATS_TEST_DIRNAME/gateway-push.toml"
}
