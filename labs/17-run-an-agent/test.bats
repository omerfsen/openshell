#!/usr/bin/env bats
# Lab 17: OpenCode image, OpenRouter profile, and the credential path.

load ../../tests/helpers

AGENT_IMAGE=ghcr.io/anomalyco/opencode:1.19.3
PROFILE=openrouter-training
FAKE=lab17-fake

setup_file() {
  ensure_tools_image
  docker image inspect "$AGENT_IMAGE" >/dev/null 2>&1 || docker pull -q "$AGENT_IMAGE" >/dev/null
  delete_sandbox lab17-fake
  openshell provider delete "$FAKE" >/dev/null 2>&1 || true
  openshell provider delete lab17-live >/dev/null 2>&1 || true
  openshell profile delete "$PROFILE" >/dev/null 2>&1 || true
  openshell profile import -f "$BATS_TEST_DIRNAME/openrouter-training.yaml" >/dev/null
  openshell provider create --name "$FAKE" --type "$PROFILE" \
    --credential OPENROUTER_API_KEY=sk-or-fake-training-key >/dev/null
  openshell sandbox create --name lab17-fake --from "$TOOLS_IMAGE" --provider "$FAKE" --detach >/dev/null
}

teardown_file() {
  delete_sandbox lab17-fake
  delete_sandbox lab17-agent
  openshell provider delete "$FAKE" >/dev/null 2>&1 || true
  openshell provider delete lab17-live >/dev/null 2>&1 || true
  openshell profile delete "$PROFILE" >/dev/null 2>&1 || true
}

@test "the agent image runs in a sandbox as a non-root user" {
  run openshell sandbox create --name lab17-agent --from "$AGENT_IMAGE" --no-auto-providers \
    --no-keep --no-tty -- sh -c 'id -u; opencode --version'
  [ "$status" -eq 0 ]
  [[ "$output" == *1000* ]]
  [[ "$output" == *1.19.3* ]]
}

@test "the sandbox sees only a placeholder for the API key" {
  run sx lab17-fake sh -c 'echo "$OPENROUTER_API_KEY"'
  [[ "$output" == openshell:resolve:env:* ]]
}

@test "the key is injected on the way to openrouter.ai" {
  # OpenRouter answers a request carrying the (fake) key differently from one
  # without an Authorization header, so this proves injection happened.
  run sx lab17-fake sh -c 'curl -s --max-time 15 -H "Authorization: Bearer $OPENROUTER_API_KEY" https://openrouter.ai/api/v1/key'
  [[ "$output" == *"Missing Authentication header"* ]]
  run sx lab17-fake curl -s --max-time 15 https://openrouter.ai/api/v1/key
  [[ "$output" == *"No cookie auth credentials found"* ]]
}

@test "other hosts stay closed" {
  run http_code lab17-fake https://example.com
  [ "$output" = "000" ]
}

@test "live agent answers through OpenRouter" {
  [ -n "${OPENROUTER_API_KEY:-}" ] || skip "set OPENROUTER_API_KEY to run the live agent test"
  openshell provider create --name lab17-live --type "$PROFILE" --from-existing >/dev/null
  run timeout 300 openshell sandbox create --name lab17-agent --from "$AGENT_IMAGE" \
    --provider lab17-live --no-keep --no-tty -- \
    opencode run -m openrouter/nvidia/nemotron-3.5-lightning:free 'Reply with exactly: OK'
  [ "$status" -eq 0 ]
  [[ "$output" == *OK* ]]
}
