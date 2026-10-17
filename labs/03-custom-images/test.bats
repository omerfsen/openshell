#!/usr/bin/env bats
# Lab 03: custom images, the non-root rule, and image-baked policy.

load ../../tests/helpers

BAKED_IMAGE="openshell-training/baked-policy:${TRAINING_VERSION}"
ROOT_IMAGE="openshell-training/rootimg:test"

setup_file() {
  ensure_tools_image
  docker build -q -t "$BAKED_IMAGE" "$REPO_ROOT/images/baked-policy" >/dev/null
  printf 'FROM ubuntu:24.04\nUSER root\n' | docker build -q -t "$ROOT_IMAGE" - >/dev/null
  create_sandbox lab03-tools
  delete_sandbox lab03-baked
  openshell sandbox create --name lab03-baked --from "$BAKED_IMAGE" --no-auto-providers --detach >/dev/null
}

teardown_file() {
  delete_sandbox lab03-tools
  delete_sandbox lab03-baked
  delete_sandbox lab03-root
}

@test "tools image provides the lab clients" {
  run sx lab03-tools sh -c 'command -v curl git jq python3 nc dig'
  [ "$status" -eq 0 ]
}

@test "python3 resolves to the real interpreter path" {
  run sx lab03-tools readlink -f /usr/bin/python3
  [ "$output" = "/usr/bin/python3.12" ]
}

@test "an image that runs as root is rejected" {
  delete_sandbox lab03-root
  run openshell sandbox create --name lab03-root --from "$ROOT_IMAGE" --no-auto-providers --detach
  [ "$status" -ne 0 ]
  [[ "$output" == *"must not contain UID or GID zero"* ]]
}

@test "image-baked policy allows GET /get" {
  run http_code lab03-baked https://postman-echo.com/get
  [ "$output" = "200" ]
}

@test "image-baked policy denies other paths on the same host" {
  run http_code lab03-baked https://postman-echo.com/headers
  [ "$output" = "403" ]
}

@test "image-baked policy is the sandbox's base policy" {
  run openshell policy get lab03-baked --base
  [[ "$output" == *"echo_get"* ]]
}
