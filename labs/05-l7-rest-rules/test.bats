#!/usr/bin/env bats
# Lab 05: L7 REST inspection, explicit allows, deny rules, audit mode.

load ../../tests/helpers

NAME=lab05-l7

setup_file() {
  ensure_tools_image
  create_sandbox "$NAME"
  openshell policy update "$NAME" --rule-name echo_api --binary /usr/bin/curl \
    --add-endpoint postman-echo.com:443:read-only:rest:enforce --wait >/dev/null
}

teardown_file() {
  delete_sandbox "$NAME"
}

@test "read-only preset allows GET" {
  run http_code "$NAME" https://postman-echo.com/get
  [ "$output" = "200" ]
}

@test "read-only preset blocks POST with a policy_denied body" {
  run sx "$NAME" curl -s --max-time 10 -X POST https://postman-echo.com/post -d '{}'
  [[ "$output" == *'"error":"policy_denied"'* ]]
  [[ "$output" == *'"layer":"l7"'* ]]
}

@test "the L7 denial is logged with method and path" {
  log_has "$NAME" 'HTTP:POST .*DENIED POST .*postman-echo\.com:443/post'
}

@test "--add-allow grants one extra method and path" {
  openshell policy update "$NAME" --rule-name echo_api --binary /usr/bin/curl \
    --add-allow 'postman-echo.com:443:POST:/post' --wait
  run openshell policy get "$NAME" --base
  [[ "$output" == *"/post"* ]]
  # Still denied for a different path.
  run http_code "$NAME" -X POST https://postman-echo.com/get
  [ "$output" = "403" ]
}

@test "a deny rule beats an allow" {
  openshell policy update "$NAME" --rule-name echo_api --binary /usr/bin/curl \
    --add-deny 'postman-echo.com:443:GET:/headers' --wait
  run http_code "$NAME" https://postman-echo.com/get
  [ "$output" = "200" ]
  run http_code "$NAME" https://postman-echo.com/headers
  [ "$output" = "403" ]
}

@test "audit mode lets violations through" {
  openshell policy update "$NAME" --rule-name httpbin_audit --binary /usr/bin/curl \
    --add-endpoint httpbin.org:443:read-only:rest:audit --wait
  run http_code "$NAME" -X POST https://httpbin.org/post
  [ "$output" = "200" ]
}

@test "switching the endpoint to enforce blocks the same request" {
  openshell policy update "$NAME" --remove-rule httpbin_audit --wait
  openshell policy update "$NAME" --rule-name httpbin_enforce --binary /usr/bin/curl \
    --add-endpoint httpbin.org:443:read-only:rest:enforce --wait
  run http_code "$NAME" -X POST https://httpbin.org/post
  [ "$output" = "403" ]
  run http_code "$NAME" https://httpbin.org/get
  [ "$output" = "200" ]
}
