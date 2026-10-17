#!/usr/bin/env bats
# Lab 08: provider profiles, credential placeholders, endpoint binding.

load ../../tests/helpers

NAME=lab08-cred
PROVIDER=lab08-echo
SECRET=training-secret-1234

setup_file() {
  ensure_tools_image
  delete_sandbox "$NAME"
  openshell provider delete "$PROVIDER" >/dev/null 2>&1 || true
  openshell profile delete echo-api >/dev/null 2>&1 || true
  openshell profile lint -f "$BATS_TEST_DIRNAME/echo-api.yaml" >/dev/null
  openshell profile import -f "$BATS_TEST_DIRNAME/echo-api.yaml" >/dev/null
  openshell provider create --name "$PROVIDER" --type echo-api --credential "DEMO_API_TOKEN=$SECRET" >/dev/null
  openshell sandbox create --name "$NAME" --from "$TOOLS_IMAGE" --provider "$PROVIDER" --detach >/dev/null
}

teardown_file() {
  delete_sandbox "$NAME"
  openshell provider delete "$PROVIDER" >/dev/null 2>&1 || true
  openshell profile delete echo-api >/dev/null 2>&1 || true
}

authorization_seen_by() {
  sx "$NAME" sh -c "curl -s --max-time 10 -H \"Authorization: Bearer \$DEMO_API_TOKEN\" $1"
}

@test "provider listing never shows the secret" {
  run openshell provider list -o json
  [[ "$output" != *"$SECRET"* ]]
  [[ "$output" == *"DEMO_API_TOKEN"* ]]
}

@test "the sandbox only sees a placeholder" {
  run sx "$NAME" sh -c 'echo "$DEMO_API_TOKEN"'
  [[ "$output" == openshell:resolve:env:* ]]
  [[ "$output" != *"$SECRET"* ]]
}

@test "the bound endpoint receives the real secret" {
  run authorization_seen_by https://httpbin.org/headers
  [[ "$output" == *"Bearer $SECRET"* ]]
}

@test "the provider contributes a network rule to the effective policy only" {
  run openshell policy get "$NAME" --full
  [[ "$output" == *"_provider_${PROVIDER//-/_}"* ]]
  run openshell policy get "$NAME" --base
  [[ "$output" != *"_provider_${PROVIDER//-/_}"* ]]
}

@test "sending the placeholder to another allowed host is refused" {
  openshell policy update "$NAME" --rule-name other_echo --binary /usr/bin/curl \
    --add-endpoint postman-echo.com:443:read-only:rest:enforce --wait
  run authorization_seen_by https://postman-echo.com/headers
  [[ "$output" == *"credential_endpoint_mismatch"* ]]
  [[ "$output" != *"$SECRET"* ]]
}

@test "the same host works without the placeholder" {
  run http_code "$NAME" https://postman-echo.com/get
  [ "$output" = "200" ]
}

@test "rotating the provider secret reaches new processes" {
  openshell provider update "$PROVIDER" --credential DEMO_API_TOKEN=rotated-5678 --wait >/dev/null
  run authorization_seen_by https://httpbin.org/headers
  [[ "$output" == *"Bearer rotated-5678"* ]]
}
