#!/usr/bin/env bash
# Remove everything the course creates on the gateway: sandboxes, providers,
# profiles, templates, global overrides, and the training images. It never
# touches the OpenShell installation itself.
#
# Usage: scripts/cleanup.sh [--images]
set -uo pipefail

# Sandbox names used by the README walkthroughs (tests use the lab* prefix).
readme_sandboxes=(first basics crashy once tools baked rooty net l7 fs life cred files editor
  adv auto prove web t-dev t-prod obs sdk-demo proto agent agent-check agent-run)

echo "Deleting course sandboxes..."
mapfile -t existing < <(openshell sandbox list 2>/dev/null | awk 'NR > 1 { print $1 }')
for name in "${existing[@]}"; do
  if [[ "$name" == lab* ]] || printf '%s\n' "${readme_sandboxes[@]}" | grep -qx "$name"; then
    openshell sandbox delete "$name" >/dev/null 2>&1 && echo "  sandbox $name"
  fi
done

echo "Deleting course providers, profiles, and templates..."
for provider in echo lab08-echo openrouter lab17-fake lab17-live; do
  openshell provider delete "$provider" >/dev/null 2>&1 && echo "  provider $provider"
done
for profile in echo-api openrouter-training; do
  openshell profile delete "$profile" >/dev/null 2>&1 && echo "  profile $profile"
done
for template in training-tools lab13-tools lab15-tools; do
  openshell sandbox template delete "$template" >/dev/null 2>&1 && echo "  template $template"
done

echo "Removing global overrides set by the labs..."
openshell policy delete --global --yes >/dev/null 2>&1 && echo "  global policy"
for key in proposal_approval_mode agent_policy_proposals_enabled ocsf_json_enabled; do
  openshell settings delete --global --key "$key" --yes >/dev/null 2>&1 && echo "  global setting $key"
done

if [[ "${1:-}" == --images ]]; then
  echo "Removing training images..."
  docker image rm -f openshell-training/tools:0.1.4 openshell-training/baked-policy:0.1.4 \
    openshell-training/rootimg:test >/dev/null 2>&1 && echo "  images"
fi

echo "Done."
