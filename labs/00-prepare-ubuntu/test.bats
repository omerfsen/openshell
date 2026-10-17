#!/usr/bin/env bats
# Lab 00: the host meets OpenShell's prerequisites.

load ../../tests/helpers

@test "host check script passes" {
  run "$REPO_ROOT/scripts/check-host.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Host is ready for OpenShell."* ]]
}

@test "Docker is reachable without sudo" {
  run docker info --format '{{.ServerVersion}}'
  [ "$status" -eq 0 ]
}

@test "Docker Engine is 28.0 or newer" {
  version="$(docker version --format '{{.Server.Version}}')"
  [ "${version%%.*}" -ge 28 ]
}

@test "Docker is not the snap package" {
  run snap list docker
  [ "$status" -ne 0 ]
}
