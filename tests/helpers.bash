# Shared helpers for the lab tests. Each lab's test.bats loads this file with
#   load ../../tests/helpers
# The tests drive a real local gateway, so they create and delete real
# sandboxes. Every sandbox name starts with "lab" so cleanup can find leftovers.

TRAINING_VERSION="$(cat "${BATS_TEST_DIRNAME}/../../VERSION")"
TOOLS_IMAGE="openshell-training/tools:${TRAINING_VERSION}"
REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"

# Run a command inside a sandbox without login-shell startup files, so the
# output is exactly what the command printed.
sx() {
  local name="$1"
  shift
  openshell sandbox exec -n "$name" --no-login-shell -- "$@"
}

# HTTP status code of a request made with curl inside the sandbox. A blocked
# connection prints 000.
http_code() {
  local name="$1"
  shift
  sx "$name" curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@" || true
}

# Retry a command until it succeeds, for changes that load asynchronously
# (approved proposals, settings polled every ~10s).
eventually() {
  local tries="${EVENTUALLY_TRIES:-10}" delay="${EVENTUALLY_DELAY:-3}"
  local i
  for ((i = 1; i <= tries; i++)); do
    if "$@"; then
      return 0
    fi
    sleep "$delay"
  done
  return 1
}

# Build the training tools image once; later calls reuse Docker's cache.
ensure_tools_image() {
  if ! docker image inspect "$TOOLS_IMAGE" >/dev/null 2>&1; then
    docker build -q -t "$TOOLS_IMAGE" "$REPO_ROOT/images/tools" >/dev/null
  fi
}

# Create a detached sandbox from the tools image. Extra arguments are passed
# to `openshell sandbox create` (for example --policy or --provider).
create_sandbox() {
  local name="$1"
  shift
  delete_sandbox "$name"
  openshell sandbox create --name "$name" --from "$TOOLS_IMAGE" \
    --no-auto-providers --detach "$@" >/dev/null
}

delete_sandbox() {
  openshell sandbox delete "$1" >/dev/null 2>&1 || true
  # Deletion can finish asynchronously; wait until the name is free.
  local i
  for ((i = 0; i < 20; i++)); do
    openshell sandbox get "$1" >/dev/null 2>&1 || return 0
    sleep 1
  done
}

# Policy events (NET:/HTTP: OCSF lines) from the sandbox log.
policy_events() {
  openshell logs "$1" --since "${2:-5m}" --source sandbox 2>/dev/null |
    grep -E '(NET|HTTP):[A-Z]+ '
}

# SSH-backed commands (upload, download, connect) run the host's OpenSSH
# client, which refuses to start when ~/.ssh/config has unsafe ownership or
# permissions. Call after `run` to turn that host problem into a clear skip.
skip_if_ssh_config_rejected() {
  if [[ "$output" == *"Bad owner or permissions on"* ]]; then
    skip "OpenSSH rejects ~/.ssh/config (fix with: chmod 600 ~/.ssh/config)"
  fi
}

# Succeeds once the sandbox log has a policy event matching an extended regex.
# Logs reach the gateway asynchronously, so poll for a few seconds.
log_has() {
  local name="$1" pattern="$2"
  EVENTUALLY_TRIES=8 EVENTUALLY_DELAY=2 eventually _log_matches "$name" "$pattern"
}

_log_matches() {
  policy_events "$1" | grep -qE "$2"
}
