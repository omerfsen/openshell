# Lab 07 — Policy lifecycle: files, revisions, rollback, global policy

**Goal:** manage policy the way you would in production: as version-controlled YAML, with
previews, verified rollouts, numbered revisions, rollback, and a gateway-wide override.
**Time:** ~25 minutes. **Prerequisite:** [Lab 06](../06-filesystem-and-process/README.md).

## Concepts

**Where the active policy comes from** (first match wins):

1. a **global policy** set by a gateway admin, which replaces every sandbox's policy;
2. the sandbox's **saved policy**, from `--policy` or `OPENSHELL_SANDBOX_POLICY` at creation
   and then every later change;
3. a policy baked into the **image** at `/etc/openshell/policy.yaml` (Lab 03);
4. the restrictive **default** (no network, default filesystem layout).

**Base vs effective.** The *base* policy is yours. The *effective* policy is base plus rules
contributed by attached providers (Lab 08). Edit from `--base`, and audit with `--full`.

**Two commands to change policy:**

| | `openshell policy update` | `openshell policy set` |
|---|---|---|
| Scope | Only `network_policies`, incremental | Replaces the whole policy |
| Use for | Add or remove rules, endpoints, allows, denies | Middleware, GraphQL/MCP/JSON-RPC, `tls: skip`, credential bindings, anything in YAML |

Every change is validated twice: by the gateway (rejected changes never become revisions)
and by the sandbox when it loads the revision. If the sandbox cannot load it, the gateway's
`policy_validation_failure_mode` decides: `fail_closed` (the default) blocks traffic, and
`retain_last_valid` keeps the old policy.

## 1. Create from a file and inspect

```shell
openshell sandbox create --name life --from openshell-training/tools:0.1.4 \
  --policy labs/07-policy-lifecycle/policy.yaml --no-auto-providers --detach

openshell policy get life --base          # header + YAML you own
openshell policy get life --full          # effective policy
openshell policy list life                # revisions and load status
```

To apply the same file to every new sandbox, `export OPENSHELL_SANDBOX_POLICY=$PWD/labs/07-policy-lifecycle/policy.yaml`.

## 2. Preview, then apply and verify

```shell
openshell policy update life --rule-name example --binary /usr/bin/curl \
  --add-endpoint example.com:443 --dry-run         # prints the resulting rules, changes nothing
openshell policy list life                          # still one revision

openshell policy update life --rule-name example --binary /usr/bin/curl \
  --add-endpoint example.com:443 --wait            # exit 0 = loaded, 1 = rejected, 124 = timeout
openshell sandbox exec -n life -- curl -s -o /dev/null -w '%{http_code}\n' https://example.com   # 200
```

A good change is verified three ways: the latest revision shows `Loaded` in `policy list`,
the effective policy contains it, and one allowed request succeeds while one that should be
blocked is blocked.

## 3. Edit the whole policy as YAML (or JSON)

Export the base policy without the header, edit it, and replace it:

```shell
openshell policy get life --base --output json | jq -e '.policy' > /tmp/base.json
jq 'del(.network_policies.example)' /tmp/base.json > /tmp/edited.json
openshell policy set life --policy /tmp/edited.json --wait
openshell sandbox exec -n life -- curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 https://example.com   # 000
```

In a real team this file lives in Git and goes through review like any other code. Lab 11
adds a formal-verification gate to that review.

## 4. Roll back

```shell
openshell policy list life
```

```text
VERSION  HASH           STATUS       CREATED  ERROR
3        ...            Loaded       ...
2        ...            Superseded   ...
1        ...            Superseded   ...
```

Revision 2 had the `example` rule. Restore it as a **new** revision. History is never
rewritten:

```shell
openshell policy get life --rev 2 --base --output json | jq -e '.policy' > /tmp/rev2.json
openshell policy set life --policy /tmp/rev2.json --wait
openshell sandbox exec -n life -- curl -s -o /dev/null -w '%{http_code}\n' https://example.com   # 200 again
openshell policy list life   # now 4 revisions
```

A failed revision shows `Failed` with a short error. `openshell policy get life --rev <N>`
prints the full error.

## 5. Global policy (gateway admin)

On a local gateway your mTLS client certificate is the platform admin. A global policy
replaces every sandbox's policy, so set it with care:

```shell
openshell policy set --global --policy labs/07-policy-lifecycle/global-policy.yaml --yes
sleep 12   # sandboxes poll for configuration about every 10 s; --wait is not available here
openshell sandbox exec -n life -- curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 https://example.com   # 000
openshell policy get life --base | grep Source      # Source: global

openshell policy update life --rule-name x --binary /usr/bin/curl --add-endpoint example.com:443 --wait
# × policy is managed globally; delete the global policy before using `openshell policy update`

openshell policy delete --global --yes
sleep 12
openshell sandbox exec -n life -- curl -s -o /dev/null -w '%{http_code}\n' https://example.com   # 200
```

Use a global policy as an emergency brake ("cut all agent egress now") or to enforce one
baseline on a shared gateway.

## 6. Clean up

```shell
openshell sandbox delete life
```

## Exercises

1. Submit a policy with an invalid field (for example `enforcement: block`). Does it become a
   revision?
2. What does `openshell policy list --global` show after you deleted the global policy?

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=07          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=07     # asciinema
labs/07-policy-lifecycle/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/07-policy-lifecycle/test.bats
```

**Next:** [Lab 08 — Providers: credentials the agent never sees](../08-providers-and-credentials/README.md)
