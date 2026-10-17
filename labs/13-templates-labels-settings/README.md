# Lab 13 — Templates, labels, and settings

**Goal:** stamp out consistent sandboxes from a reusable template, organize fleets with
labels, and change runtime behavior with settings.
**Time:** ~15 minutes. **Prerequisite:** [Lab 12](../12-ports-and-services/README.md).

## Concepts

- **Workload template**: a named runtime shape: image, CPU, memory, GPU, environment,
  driver config. `--template` cannot be mixed with `--from`, `--cpu`, `--memory`, `--gpu`,
  `--env`, or `--driver-config-json`. Policy and providers stay per sandbox, so every
  sandbox from a template keeps **its own** access boundary.
- **Labels**: `key=value` tags on sandboxes, templates, and providers, used for selectors such
  as `env=dev,team=platform`.
- **Settings**: typed runtime switches, set per sandbox or gateway-wide (`--global`). A
  global value overrides sandbox values. Sandboxes poll for changes about every 10 seconds,
  with no restart.

| Setting | Effect |
|---|---|
| `agent_policy_proposals_enabled` | Policy advisor guide + `policy.local` API (Lab 10) |
| `proposal_approval_mode` | `manual` or `auto` approval of proposals (Lab 10) |
| `ocsf_json_enabled` | Full OCSF JSON audit records on the supervisor's stderr (Lab 14) |
| `ocsf_schema_version` | Pin the OCSF schema version of those records |

## 1. Create a template

```shell
openshell sandbox template create training-tools \
  --image openshell-training/tools:0.1.4 \
  --cpu 1 --memory 1Gi \
  --env COURSE=openshell-training \
  --label course=openshell-training
openshell sandbox template list
openshell sandbox template get training-tools
```

## 2. Create labeled sandboxes from it

```shell
openshell sandbox create --name t-dev  --template training-tools --label env=dev  --label team=a --no-auto-providers --detach
openshell sandbox create --name t-prod --template training-tools --label env=prod --label team=a --no-auto-providers --detach
openshell sandbox exec -n t-dev -- sh -c 'echo $COURSE; command -v curl'
```

Each sandbox inherits the image and environment from the template. Try mixing flags:

```shell
openshell sandbox create --name t-bad --template training-tools --from ubuntu:24.04
# error: the argument '--template <TEMPLATE>' cannot be used with '--from <FROM>'
```

## 3. Select by label

```shell
openshell sandbox list --selector env=dev
openshell sandbox list --selector team=a
openshell sandbox list --selector env=prod,team=a
```

## 4. Settings

```shell
openshell settings get t-dev
openshell settings set t-dev --key ocsf_json_enabled --value true
openshell settings get t-dev          # ocsf_json_enabled = true (sandbox)
openshell settings delete t-dev --key ocsf_json_enabled
```

Gateway-wide (admin) values win over sandbox values. Use them to enforce a rule fleet-wide:

```shell
openshell settings set --global --key proposal_approval_mode --value manual --yes
openshell settings get t-dev          # proposal_approval_mode = manual (global)
openshell settings delete --global --key proposal_approval_mode --yes
```

## 5. Clean up

```shell
openshell sandbox delete t-dev t-prod
openshell sandbox template delete training-tools
```

## Exercises

1. Create a second template with `--memory 256Mi` and run something memory-hungry in it.
2. Label a provider (`openshell provider create ... --label team=a`) and list providers with
   `--label-selector team=a`.

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=13          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=13     # asciinema
labs/13-templates-labels-settings/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/13-templates-labels-settings/test.bats
```

**Next:** [Lab 14 — Observability: logs and OCSF audit events](../14-observability/README.md)
