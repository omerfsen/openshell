#!/usr/bin/env bats
# Lab 07: policy files, dry runs, revisions, rollback, global policy.

load ../../tests/helpers

NAME=lab07-life

setup_file() {
  ensure_tools_image
  create_sandbox "$NAME" --policy "$BATS_TEST_DIRNAME/policy.yaml"
}

teardown_file() {
  # Never leave a global policy behind: it would affect every sandbox.
  openshell policy delete --global --yes >/dev/null 2>&1 || true
  delete_sandbox "$NAME"
}

revision_count() {
  openshell policy list "$NAME" | tail -n +2 | grep -c .
}

@test "--policy file becomes the base policy" {
  run openshell policy get "$NAME" --base
  [[ "$output" == *"echo_api"* ]]
  run http_code "$NAME" https://postman-echo.com/get
  [ "$output" = "200" ]
}

@test "--dry-run does not create a revision" {
  before="$(revision_count)"
  run openshell policy update "$NAME" --rule-name example --binary /usr/bin/curl \
    --add-endpoint example.com:443 --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"example.com"* ]]
  [ "$(revision_count)" -eq "$before" ]
}

@test "--wait applies and loads the change" {
  run openshell policy update "$NAME" --rule-name example --binary /usr/bin/curl \
    --add-endpoint example.com:443 --wait
  [ "$status" -eq 0 ]
  [[ "$output" == *"loaded"* ]]
  run http_code "$NAME" https://example.com
  [ "$output" = "200" ]
}

@test "policy set replaces the whole policy from JSON" {
  openshell policy get "$NAME" --base --output json | jq -e '.policy' |
    jq 'del(.network_policies.example)' >"$BATS_TEST_TMPDIR/edited.json"
  run openshell policy set "$NAME" --policy "$BATS_TEST_TMPDIR/edited.json" --wait
  [ "$status" -eq 0 ]
  run http_code "$NAME" https://example.com
  [ "$output" = "000" ]
}

@test "rolling back re-applies an earlier revision as a new one" {
  latest="$(openshell policy list "$NAME" | awk 'NR == 2 { print $1 }')"
  previous=$((latest - 1))
  openshell policy get "$NAME" --rev "$previous" --base --output json |
    jq -e '.policy' >"$BATS_TEST_TMPDIR/rollback.json"
  run openshell policy set "$NAME" --policy "$BATS_TEST_TMPDIR/rollback.json" --wait
  [ "$status" -eq 0 ]
  run http_code "$NAME" https://example.com
  [ "$output" = "200" ]
  [ "$(openshell policy list "$NAME" | awk 'NR == 2 { print $1 }')" -eq $((latest + 1)) ]
}

@test "an invalid policy is rejected by the gateway" {
  sed 's/enforcement: enforce/enforcement: block/' "$BATS_TEST_DIRNAME/policy.yaml" >"$BATS_TEST_TMPDIR/bad.yaml"
  before="$(revision_count)"
  run openshell policy set "$NAME" --policy "$BATS_TEST_TMPDIR/bad.yaml" --wait
  [ "$status" -ne 0 ]
  [ "$(revision_count)" -eq "$before" ]
}

@test "a global policy overrides the sandbox and blocks updates" {
  openshell policy set --global --policy "$BATS_TEST_DIRNAME/global-policy.yaml" --yes
  EVENTUALLY_TRIES=10 EVENTUALLY_DELAY=3 eventually bash -c \
    "[ \"\$(openshell sandbox exec -n $NAME --no-login-shell -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 https://example.com)\" = 000 ]"
  run openshell policy update "$NAME" --rule-name x --binary /usr/bin/curl --add-endpoint example.com:443 --wait
  [ "$status" -ne 0 ]
  [[ "$output" == *"managed globally"* ]]
}

@test "deleting the global policy restores the sandbox policy" {
  openshell policy delete --global --yes
  EVENTUALLY_TRIES=10 EVENTUALLY_DELAY=3 eventually bash -c \
    "[ \"\$(openshell sandbox exec -n $NAME --no-login-shell -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 https://example.com)\" = 200 ]"
}
