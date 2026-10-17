#!/usr/bin/env bash
# Lab 17 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 17 — Run a real AI agent (credential path shown with a fake key)"
run_quiet 'openshell sandbox delete agent-check; openshell provider delete openrouter; openshell profile delete openrouter-training'
run 'cat labs/17-run-an-agent/openrouter-training.yaml'
run 'openshell profile import -f labs/17-run-an-agent/openrouter-training.yaml'
say "Use --from-existing with your real OPENROUTER_API_KEY; this replay uses a fake key"
run 'openshell provider create --name openrouter --type openrouter-training --credential OPENROUTER_API_KEY=sk-or-fake-training-key'
run 'openshell sandbox create --name agent-check --from openshell-training/tools:0.1.4 --provider openrouter --detach'
run "openshell sandbox exec -n agent-check -- sh -c 'echo \"\$OPENROUTER_API_KEY\"'"
run "openshell sandbox exec -n agent-check -- sh -c 'curl -s -H \"Authorization: Bearer \$OPENROUTER_API_KEY\" https://openrouter.ai/api/v1/key'; echo"
say "The agent image runs as UID 1000 inside the boundary"
run "openshell sandbox create --name agent-probe --from ghcr.io/anomalyco/opencode:1.19.3 --no-auto-providers --no-keep --no-tty -- sh -c 'id; opencode --version'"
say "With a real key: openshell sandbox create --name agent --from ghcr.io/anomalyco/opencode:1.19.3 --provider openrouter -- opencode -m openrouter/nvidia/nemotron-3.5-lightning:free"
run 'openshell sandbox delete agent-check; openshell provider delete openrouter; openshell profile delete openrouter-training'
