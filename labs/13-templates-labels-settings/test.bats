#!/usr/bin/env bats
# Lab 13: workload templates, label selectors, sandbox and global settings.

load ../../tests/helpers

TEMPLATE=lab13-tools

setup_file() {
  ensure_tools_image
  openshell sandbox template delete "$TEMPLATE" >/dev/null 2>&1 || true
  openshell sandbox template create "$TEMPLATE" --image "$TOOLS_IMAGE" --cpu 1 --memory 1Gi \
    --env COURSE=openshell-training --label course=openshell-training >/dev/null
  for env in dev prod; do
    delete_sandbox "lab13-$env"
    openshell sandbox create --name "lab13-$env" --template "$TEMPLATE" \
      --label "env=$env" --label team=lab13 --no-auto-providers --detach >/dev/null
  done
}

teardown_file() {
  openshell settings delete --global --key proposal_approval_mode --yes >/dev/null 2>&1 || true
  delete_sandbox lab13-dev
  delete_sandbox lab13-prod
  openshell sandbox template delete "$TEMPLATE" >/dev/null 2>&1 || true
}

@test "template is listed" {
  run openshell sandbox template list
  [[ "$output" == *"$TEMPLATE"* ]]
}

@test "sandboxes inherit image and env from the template" {
  run sx lab13-dev sh -c 'echo $COURSE; command -v curl'
  [ "${lines[0]}" = "openshell-training" ]
  [ "${lines[1]}" = "/usr/bin/curl" ]
}

@test "--template cannot be combined with --from" {
  run openshell sandbox create --name lab13-bad --template "$TEMPLATE" --from ubuntu:24.04 --no-auto-providers --detach
  delete_sandbox lab13-bad
  [ "$status" -ne 0 ]
}

@test "label selectors filter sandboxes" {
  run openshell sandbox list --selector env=dev,team=lab13
  [[ "$output" == *lab13-dev* ]]
  [[ "$output" != *lab13-prod* ]]
  run openshell sandbox list --selector team=lab13
  [[ "$output" == *lab13-dev* ]]
  [[ "$output" == *lab13-prod* ]]
}

@test "a sandbox setting can be set and deleted" {
  openshell settings set lab13-dev --key ocsf_json_enabled --value true
  run openshell settings get lab13-dev
  [[ "$output" == *"ocsf_json_enabled = true"* ]]
  openshell settings delete lab13-dev --key ocsf_json_enabled
  run openshell settings get lab13-dev
  [[ "$output" == *"ocsf_json_enabled = <unset>"* ]]
}

@test "a global setting applies to every sandbox" {
  openshell settings set --global --key proposal_approval_mode --value manual --yes
  run openshell settings get lab13-prod
  [[ "$output" == *"proposal_approval_mode = manual"* ]]
  openshell settings delete --global --key proposal_approval_mode --yes
}
