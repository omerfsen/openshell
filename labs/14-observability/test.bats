#!/usr/bin/env bats
# Lab 14: shorthand OCSF logs and full OCSF JSON from the supervisor.

load ../../tests/helpers

NAME=lab14-obs

setup_file() {
  ensure_tools_image
  create_sandbox "$NAME"
  openshell policy update "$NAME" --rule-name echo_api --binary /usr/bin/curl \
    --add-endpoint postman-echo.com:443:read-only:rest:enforce --wait >/dev/null
  http_code "$NAME" https://postman-echo.com/get >/dev/null
  http_code "$NAME" -X POST https://postman-echo.com/get >/dev/null
  http_code "$NAME" https://example.com >/dev/null
}

teardown_file() {
  delete_sandbox "$NAME"
}

supervisor_container() {
  docker ps --format '{{.Names}}' | grep -- "--${NAME}-.*-supervisor$" | head -1
}

@test "allowed connections are logged with the matching rule" {
  log_has "$NAME" 'NET:OPEN .*ALLOWED /usr/bin/curl.*postman-echo\.com:443 \[policy:echo_api engine:opa\]'
}

@test "L7 denials are logged with the l7 engine" {
  log_has "$NAME" 'HTTP:POST .*DENIED .*\[policy:echo_api engine:l7\]'
}

@test "L4 denials are logged with a reason" {
  log_has "$NAME" 'NET:OPEN .*DENIED /usr/bin/curl.*example\.com:443 \[reason:'
}

@test "the supervisor runs as its own container" {
  [ -n "$(supervisor_container)" ]
}

has_ocsf_json() {
  http_code "$NAME" https://example.com >/dev/null
  docker logs --since 2m "$(supervisor_container)" 2>&1 | grep -q ' OCSF-JSON {'
}

@test "ocsf_json_enabled emits parseable OCSF JSON" {
  openshell settings set "$NAME" --key ocsf_json_enabled --value true
  EVENTUALLY_TRIES=10 EVENTUALLY_DELAY=3 eventually has_ocsf_json
  run bash -c "docker logs --since 2m '$(supervisor_container)' 2>&1 | grep ' OCSF-JSON {' | tail -1 | sed 's/.* OCSF-JSON //' | jq -r .class_uid"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
}
