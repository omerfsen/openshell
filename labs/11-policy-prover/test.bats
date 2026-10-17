#!/usr/bin/env bats
# Lab 11: openshell-prover boundary checks and the CI gate.

load ../../tests/helpers

cd_lab() { cd "$BATS_TEST_DIRNAME"; }

prove() {
  openshell-prover check "$1" --boundary "$2" --output json | jq -r .result
}

@test "filesystem subset is within the boundary" {
  cd_lab
  [ "$(prove candidates/fs-read-usr.yaml boundary-fs.yaml)" = within_boundary ]
}

@test "extra write access exceeds the boundary with a counterexample" {
  cd_lab
  run openshell-prover check candidates/fs-write-tmp.yaml --boundary boundary-fs.yaml
  [ "$status" -eq 1 ]
  [[ "$output" == *"counterexample: filesystem write /tmp"* ]]
}

@test "narrower network access is within the boundary" {
  cd_lab
  [ "$(prove candidates/narrow.yaml boundary.yaml)" = within_boundary ]
}

@test "an extra binary exceeds the boundary" {
  cd_lab
  [ "$(prove candidates/extra-binary.yaml boundary.yaml)" = exceeds_boundary ]
}

@test "a write method exceeds the boundary" {
  cd_lab
  run openshell-prover check candidates/write-method.yaml --boundary boundary.yaml --output json
  [ "$status" -eq 1 ]
  [ "$(jq -r .counterexample.method <<<"$output")" != GET ]
}

@test "GraphQL rules are reported as unsupported, not passed" {
  cd_lab
  run openshell-prover check candidates/graphql.yaml --boundary boundary.yaml
  [ "$status" -eq 3 ]
  [[ "$output" == *"result: unsupported"* ]]
}

@test "the CI gate fails when any policy is not within the boundary" {
  cd_lab
  run ./prove-all.sh boundary.yaml candidates/narrow.yaml candidates/extra-binary.yaml
  [ "$status" -eq 1 ]
  [[ "$output" == *"PASS  candidates/narrow.yaml"* ]]
  [[ "$output" == *"FAIL  candidates/extra-binary.yaml"* ]]
}

@test "the CI gate passes when every policy is within the boundary" {
  cd_lab
  run ./prove-all.sh boundary.yaml candidates/narrow.yaml
  [ "$status" -eq 0 ]
}

@test "a live sandbox policy can be exported and proven" {
  ensure_tools_image
  create_sandbox lab11-prove
  openshell policy update lab11-prove --rule-name echo_read --binary /usr/bin/curl \
    --add-endpoint postman-echo.com:443:read-only:rest:enforce --wait
  openshell sandbox get lab11-prove --policy-only >"$BATS_TEST_TMPDIR/live.yaml"
  within="$(prove "$BATS_TEST_TMPDIR/live.yaml" "$BATS_TEST_DIRNAME/boundary.yaml")"
  openshell policy update lab11-prove --rule-name py --binary /usr/bin/python3.12 \
    --add-endpoint postman-echo.com:443:read-only:rest:enforce --wait
  openshell sandbox get lab11-prove --policy-only >"$BATS_TEST_TMPDIR/live.yaml"
  exceeds="$(prove "$BATS_TEST_TMPDIR/live.yaml" "$BATS_TEST_DIRNAME/boundary.yaml")"
  delete_sandbox lab11-prove
  [ "$within" = within_boundary ]
  [ "$exceeds" = exceeds_boundary ]
}
