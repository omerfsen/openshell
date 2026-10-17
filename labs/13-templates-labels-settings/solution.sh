#!/usr/bin/env bash
# Lab 13 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 13 — Templates, labels, and settings"
run_quiet 'openshell sandbox delete t-dev t-prod; openshell sandbox template delete training-tools'
run 'openshell sandbox template create training-tools --image openshell-training/tools:0.1.4 --cpu 1 --memory 1Gi --env COURSE=openshell-training --label course=openshell-training'
run 'openshell sandbox template list'
run 'openshell sandbox create --name t-dev --template training-tools --label env=dev --label team=a --no-auto-providers --detach'
run 'openshell sandbox create --name t-prod --template training-tools --label env=prod --label team=a --no-auto-providers --detach'
run "openshell sandbox exec -n t-dev -- sh -c 'echo \$COURSE; command -v curl'"
run 'openshell sandbox create --name t-bad --template training-tools --from ubuntu:24.04'
say "Select by label"
run 'openshell sandbox list --selector env=dev'
run 'openshell sandbox list --selector team=a'
say "Settings: per sandbox and gateway-wide"
run 'openshell settings set t-dev --key ocsf_json_enabled --value true'
run 'openshell settings set --global --key proposal_approval_mode --value manual --yes'
run 'openshell settings get t-dev'
run 'openshell settings delete --global --key proposal_approval_mode --yes; openshell settings delete t-dev --key ocsf_json_enabled'
run 'openshell sandbox delete t-dev t-prod; openshell sandbox template delete training-tools'
