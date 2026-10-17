#!/usr/bin/env bats
# Lab 02: sandbox lifecycle with the default image.

load ../../tests/helpers

NAME=lab02-basics

setup_file() {
  delete_sandbox "$NAME"
  openshell sandbox create --name "$NAME" --no-auto-providers --detach >/dev/null
}

teardown_file() {
  delete_sandbox "$NAME"
  delete_sandbox lab02-once
}

@test "sandbox reaches the Ready phase" {
  run openshell sandbox list
  [[ "$output" =~ $NAME[[:space:]].*Ready ]]
}

@test "workload runs as a non-root user" {
  run sx "$NAME" id -u
  [ "$status" -eq 0 ]
  [ "$output" -ne 0 ]
}

@test "default image is minimal Ubuntu 24.04 without curl" {
  run sx "$NAME" sh -c '. /etc/os-release; echo $VERSION_ID'
  [ "$output" = "24.04" ]
  run sx "$NAME" sh -c 'command -v curl || exit 1'
  [ "$status" -ne 0 ]
}

@test "working directory is writable, /etc is not" {
  run sx "$NAME" sh -c 'touch ./probe && echo ok'
  [ "$output" = "ok" ]
  run sx "$NAME" sh -c 'echo x > /etc/probe'
  [ "$status" -ne 0 ]
}

@test "exec propagates the exit code" {
  run sx "$NAME" sh -c 'exit 3'
  [ "$status" -eq 3 ]
}

@test "exec passes stdin and per-command env" {
  run bash -c "echo piped | openshell sandbox exec -n $NAME --no-login-shell -- cat"
  [ "$output" = "piped" ]
  run openshell sandbox exec -n "$NAME" --no-login-shell --env GREETING=merhaba -- sh -c 'echo $GREETING'
  [ "$output" = "merhaba" ]
}

@test "stop keeps the workspace and start brings it back" {
  sx "$NAME" sh -c 'echo kept > ./keep.txt'
  openshell sandbox stop "$NAME"
  run openshell sandbox list
  [[ "$output" =~ $NAME[[:space:]].*Stopped ]]
  openshell sandbox start "$NAME"
  run sx "$NAME" cat ./keep.txt
  [ "$output" = "kept" ]
}

@test "--no-keep deletes the sandbox when its command exits" {
  run openshell sandbox create --name lab02-once --no-auto-providers --no-keep --no-tty -- echo done
  [ "$status" -eq 0 ]
  [[ "$output" == *done* ]]
  sleep 2
  run openshell sandbox get lab02-once
  [ "$status" -ne 0 ]
}
