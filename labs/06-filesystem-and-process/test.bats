#!/usr/bin/env bats
# Lab 06: Landlock filesystem rules, process identity, startup-locked sections.

load ../../tests/helpers

NAME=lab06-fs
POLICY="$BATS_TEST_DIRNAME/policy.yaml"

setup_file() {
  ensure_tools_image
  create_sandbox "$NAME" --policy "$POLICY"
}

teardown_file() {
  delete_sandbox "$NAME"
}

@test "process runs as the pinned UID and GID" {
  run sx "$NAME" sh -c 'echo "$(id -u):$(id -g)"'
  [ "$output" = "1000:1000" ]
}

@test "working directory and /tmp are writable" {
  run sx "$NAME" sh -c 'echo a > ./w && echo b > /tmp/w && echo ok'
  [ "$output" = "ok" ]
}

@test "/etc is read-only" {
  run sx "$NAME" cat /etc/os-release
  [ "$status" -eq 0 ]
  run sx "$NAME" sh -c 'echo x > /etc/x'
  [ "$status" -ne 0 ]
}

@test "paths outside the policy are not even listable" {
  run sx "$NAME" ls /opt
  [ "$status" -ne 0 ]
  [[ "$output" == *"Permission denied"* ]]
}

@test "the runtime's private directory is protected" {
  run sx "$NAME" ls /.openshell
  [ "$status" -ne 0 ]
}

@test "an added path is saved but not applied to the running workload" {
  added="$BATS_TEST_TMPDIR/fs-add.yaml"
  sed 's#    - /dev/urandom#    - /dev/urandom\n    - /opt#' "$POLICY" >"$added"
  run openshell policy set "$NAME" --policy "$added" --wait
  [ "$status" -eq 0 ]
  run sx "$NAME" ls /opt
  [ "$status" -ne 0 ]
}

@test "removing a filesystem path on a live sandbox is rejected" {
  removed="$BATS_TEST_TMPDIR/fs-remove.yaml"
  grep -v /dev/urandom "$POLICY" >"$removed"
  run openshell policy set "$NAME" --policy "$removed" --wait
  [[ "$output" == *"cannot be removed on a live sandbox"* ]]
}

@test "changing Landlock on a live sandbox is rejected" {
  changed="$BATS_TEST_TMPDIR/fs-ll.yaml"
  sed 's/hard_requirement/best_effort/' "$POLICY" >"$changed"
  run openshell policy set "$NAME" --policy "$changed" --wait
  [[ "$output" == *"cannot be changed on a live sandbox"* ]]
}

@test "a recreated sandbox applies the added path" {
  added="$BATS_TEST_TMPDIR/fs-add.yaml"
  sed 's#    - /dev/urandom#    - /dev/urandom\n    - /opt#' "$POLICY" >"$added"
  create_sandbox lab06-fs2 --policy "$added"
  run sx lab06-fs2 ls /opt
  delete_sandbox lab06-fs2
  [ "$status" -eq 0 ]
}

@test "a non-numeric run_as_user is rejected" {
  bad="$BATS_TEST_TMPDIR/bad-user.yaml"
  sed 's/run_as_user: "1000"/run_as_user: ubuntu/' "$POLICY" >"$bad"
  run openshell sandbox create --name lab06-bad --from "$TOOLS_IMAGE" --policy "$bad" --no-auto-providers --detach
  delete_sandbox lab06-bad
  [ "$status" -ne 0 ]
  [[ "$output" == *"numeric"* ]]
}
