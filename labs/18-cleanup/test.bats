#!/usr/bin/env bats
# Lab 18: the cleanup script removes course resources and keeps the install.

load ../../tests/helpers

setup_file() {
  ensure_tools_image
  create_sandbox lab18-leftover
}

@test "cleanup script removes course sandboxes" {
  run "$REPO_ROOT/scripts/cleanup.sh"
  [ "$status" -eq 0 ]
  run openshell sandbox list
  [[ "$output" != *lab18-leftover* ]]
}

@test "cleanup leaves no global policy behind" {
  run openshell policy get --global --full
  [[ "$output" != *"Status:       Effective"* ]]
}

@test "the OpenShell installation is untouched" {
  run openshell status
  [[ "$output" == *"Status: Connected"* ]]
}
