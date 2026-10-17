#!/usr/bin/env bats
# Lab 04: default-deny egress and binary-scoped network rules.

load ../../tests/helpers

NAME=lab04-net

setup_file() {
  ensure_tools_image
  create_sandbox "$NAME"
}

teardown_file() {
  delete_sandbox "$NAME"
}

@test "outbound connections are denied by default" {
  run http_code "$NAME" https://postman-echo.com/get
  [ "$output" = "000" ]
}

@test "the denial is logged with binary and destination" {
  log_has "$NAME" 'DENIED /usr/bin/curl.*postman-echo\.com:443'
}

@test "a rule for curl opens the host for curl" {
  run openshell policy update "$NAME" --rule-name echo_api --binary /usr/bin/curl \
    --add-endpoint postman-echo.com:443 --wait
  [ "$status" -eq 0 ]
  run http_code "$NAME" https://postman-echo.com/get
  [ "$output" = "200" ]
}

@test "the same host stays closed for python3" {
  run sx "$NAME" python3 -c 'import urllib.request; urllib.request.urlopen("https://postman-echo.com/get", timeout=8)'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Permission denied"* ]]
}

@test "the cloud metadata address cannot be allowed" {
  run openshell policy update "$NAME" --rule-name meta --binary /usr/bin/curl \
    --add-endpoint 169.254.169.254:80 --wait
  [[ "$output" == *"regardless of policy"* ]]
  run http_code "$NAME" http://169.254.169.254/latest/meta-data/
  [ "$output" = "000" ]
}

@test "loopback inside the sandbox works" {
  run sx "$NAME" sh -c 'python3 -m http.server 9000 --bind 127.0.0.1 >/dev/null 2>&1 & sleep 1; curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9000/'
  [ "$output" = "200" ]
}

@test "removing the rule closes the host again" {
  openshell policy update "$NAME" --remove-rule echo_api --wait
  run http_code "$NAME" https://postman-echo.com/get
  [ "$output" = "000" ]
}

@test "every change is a policy revision" {
  run openshell policy list "$NAME"
  [[ "$output" == *"Loaded"* ]]
  [[ "$output" == *"Superseded"* ]]
}
