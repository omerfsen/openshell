#!/usr/bin/env bats
# Lab 15: the Python SDK creates, uses, and deletes a sandbox.

load ../../tests/helpers

TEMPLATE=lab15-tools
VENV="${LAB15_VENV:-${BATS_FILE_TMPDIR:-/tmp}/lab15-venv}"

setup_file() {
  ensure_tools_image
  export VENV="${LAB15_VENV:-$BATS_FILE_TMPDIR/lab15-venv}"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q "openshell==${TRAINING_VERSION}"
  openshell sandbox template delete "$TEMPLATE" >/dev/null 2>&1 || true
  openshell sandbox template create "$TEMPLATE" --image "$TOOLS_IMAGE" >/dev/null
}

teardown_file() {
  delete_sandbox lab15-sdk
  openshell sandbox template delete "$TEMPLATE" >/dev/null 2>&1 || true
}

@test "SDK matches the course version" {
  run "$VENV/bin/pip" show openshell
  [[ "$output" == *"Version: ${TRAINING_VERSION}"* ]]
}

@test "SDK demo creates, runs in, and deletes a sandbox" {
  run "$VENV/bin/python" "$BATS_TEST_DIRNAME/sdk_demo.py" "$TEMPLATE" lab15-sdk
  [ "$status" -eq 0 ]
  [[ "$output" == *"gateway version: ${TRAINING_VERSION}"* ]]
  [[ "$output" == *"exit code: 0"* ]]
  [[ "$output" == *"sandbox deleted"* ]]
  run openshell sandbox get lab15-sdk
  [ "$status" -ne 0 ]
}
