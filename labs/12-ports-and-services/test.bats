#!/usr/bin/env bats
# Lab 12: SSH port forward, gRPC service forward, exposed service URL.

load ../../tests/helpers

NAME=lab12-web
# `forward start` uses the same port number locally and in the sandbox.
PORT=8012
GRPC_LOCAL=18012
SSH_LOCAL=$PORT

setup_file() {
  ensure_tools_image
  delete_sandbox "$NAME"
  openshell sandbox create --name "$NAME" --from "$TOOLS_IMAGE" --no-auto-providers --detach \
    -- python3 -m http.server "$PORT" --bind 127.0.0.1 --directory /tmp >/dev/null
  sx "$NAME" sh -c 'echo lab12-ok > /tmp/index.html'
  EVENTUALLY_TRIES=10 EVENTUALLY_DELAY=1 eventually \
    bash -c "openshell sandbox exec -n $NAME --no-login-shell -- curl -sf http://127.0.0.1:$PORT/ >/dev/null"
}

teardown_file() {
  openshell forward stop "$SSH_LOCAL" "$NAME" >/dev/null 2>&1 || true
  openshell service delete "$NAME" >/dev/null 2>&1 || true
  delete_sandbox "$NAME"
}

@test "the server answers on loopback inside the sandbox" {
  run sx "$NAME" curl -s "http://127.0.0.1:$PORT/"
  [ "$output" = "lab12-ok" ]
}

@test "gRPC service forward reaches the server" {
  # Close fd 3 so bats does not wait for the background forward.
  openshell forward service "$NAME" --target-port "$PORT" --local "$GRPC_LOCAL" >/dev/null 2>&1 3>&- &
  pid=$!
  EVENTUALLY_TRIES=10 EVENTUALLY_DELAY=1 eventually curl -sf -m 5 "http://127.0.0.1:$GRPC_LOCAL/" -o /dev/null
  run curl -s -m 10 "http://127.0.0.1:$GRPC_LOCAL/"
  kill "$pid" 2>/dev/null || true
  [ "$output" = "lab12-ok" ]
}

@test "SSH port forward reaches the server" {
  # The background forward inherits stdout, so capture it in a file rather
  # than with `run`, which would wait for the pipe to close.
  log="$BATS_TEST_TMPDIR/forward.log"
  status=0
  openshell forward start "127.0.0.1:$SSH_LOCAL" "$NAME" -d </dev/null >"$log" 2>&1 3>&- || status=$?
  output="$(cat "$log")"
  skip_if_ssh_config_rejected
  [ "$status" -eq 0 ]
  run curl -s -m 10 "http://127.0.0.1:$SSH_LOCAL/"
  [ "$output" = "lab12-ok" ]
  run openshell forward list
  [[ "$output" == *"$NAME"* ]]
  openshell forward stop "$SSH_LOCAL" "$NAME"
}

@test "an exposed service gets a gateway URL" {
  run openshell service expose "$NAME" "$PORT"
  [ "$status" -eq 0 ]
  url="$(grep -o 'http://[^ ]*' <<<"$output" | head -1)"
  [ -n "$url" ]
  run curl -s -m 10 "$url"
  [ "$output" = "lab12-ok" ]
}

@test "exposed services strip Authorization by default" {
  run openshell service list
  [[ "$output" == *"$NAME"*"strip"* ]]
}

@test "deleting the service removes the URL" {
  openshell service delete "$NAME"
  run openshell service list
  [[ "$output" != *"$NAME"* ]]
}
