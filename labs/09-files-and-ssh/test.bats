#!/usr/bin/env bats
# Lab 09: upload (with .gitignore filtering), download confinement, ssh-config.

load ../../tests/helpers

NAME=lab09-files
PROJECT="$BATS_TEST_DIRNAME/sample-project"

setup_file() {
  ensure_tools_image
  create_sandbox "$NAME"
  mkdir -p "$PROJECT/build"
  echo junk >"$PROJECT/build/artifact.bin"
  echo junk >"$PROJECT/debug.log"
}

teardown_file() {
  delete_sandbox "$NAME"
  rm -rf "$PROJECT/build" "$PROJECT/debug.log"
}

@test "ssh-config prints a ProxyCommand host block" {
  run openshell sandbox ssh-config "$NAME"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Host openshell-${NAME}.default"* ]]
  [[ "$output" == *"ProxyCommand"*"ssh-proxy"* ]]
}

@test "upload copies tracked files and skips .gitignore'd ones" {
  run openshell sandbox upload "$NAME" "$PROJECT"
  skip_if_ssh_config_rejected
  [ "$status" -eq 0 ]
  run sx "$NAME" find sample-project -type f
  [[ "$output" == *"sample-project/src/app.py"* ]]
  [[ "$output" != *"artifact.bin"* ]]
  [[ "$output" != *"debug.log"* ]]
}

@test "uploaded code runs in the sandbox" {
  run sx "$NAME" python3 sample-project/src/app.py
  [ "$status" -eq 0 ] || skip "upload did not run"
  [ "$output" = "hello from the uploaded project" ]
}

@test "download fetches files from the working directory" {
  sx "$NAME" sh -c 'mkdir -p out && echo report-ok > out/report.txt'
  run openshell sandbox download "$NAME" out "$BATS_TEST_TMPDIR/out"
  skip_if_ssh_config_rejected
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/out/report.txt")" = "report-ok" ]
}

@test "download refuses paths outside the working directory" {
  run openshell sandbox download "$NAME" /etc/passwd "$BATS_TEST_TMPDIR/passwd"
  [ "$status" -ne 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/passwd" ]
}
