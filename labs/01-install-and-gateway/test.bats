#!/usr/bin/env bats
# Lab 01: OpenShell is installed at the course version and the gateway is up.

load ../../tests/helpers

@test "CLI is the course version" {
  run openshell --version
  [ "$status" -eq 0 ]
  [ "$output" = "openshell ${TRAINING_VERSION}" ]
}

@test "gateway and prover binaries are installed" {
  run openshell-gateway --version
  [[ "$output" == *"${TRAINING_VERSION}"* ]]
  run openshell-prover --version
  [[ "$output" == *"${TRAINING_VERSION}"* ]]
}

@test "gateway user service is active" {
  run systemctl --user is-active openshell-gateway
  [ "$output" = "active" ]
}

@test "CLI is connected and authenticated to the gateway" {
  run openshell status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status: Connected"* ]]
  [[ "$output" == *"Version: ${TRAINING_VERSION}"* ]]
}

@test "gateway uses the Docker compute driver" {
  run openshell gateway info
  [ "$status" -eq 0 ]
  [[ "$output" == *"docker"* ]]
}

@test "example gateway.toml passes preflight" {
  run openshell-gateway config preflight --path "$BATS_TEST_DIRNAME/gateway.toml"
  [ "$status" -eq 0 ]
}

@test "a legacy v1 config fails preflight" {
  bad="$BATS_TEST_TMPDIR/bad.toml"
  sed 's/compute_driver = "docker"/compute_drivers = ["docker"]/' \
    "$BATS_TEST_DIRNAME/gateway.toml" >"$bad"
  run openshell-gateway config preflight --path "$bad"
  [ "$status" -ne 0 ]
  [[ "$output" == *"preflight failed"* ]]
}
