#!/usr/bin/env bash
# Lab 07 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 07 — Policy lifecycle"
run_quiet 'openshell sandbox delete life'
run 'openshell sandbox create --name life --from openshell-training/tools:0.1.4 --policy labs/07-policy-lifecycle/policy.yaml --no-auto-providers --detach'
run "openshell policy get life --base | sed -n '/network_policies/,\$p'"
say "Preview, then apply and verify"
run "openshell policy update life --rule-name example --binary /usr/bin/curl --add-endpoint example.com:443 --dry-run | tail -8"
run 'openshell policy update life --rule-name example --binary /usr/bin/curl --add-endpoint example.com:443 --wait'
run "openshell sandbox exec -n life -- curl -s -o /dev/null -w '%{http_code}\n' https://example.com"
say "Edit the whole policy as JSON"
run "openshell policy get life --base --output json | jq -e '.policy' | jq 'del(.network_policies.example)' > /tmp/edited.json"
run 'openshell policy set life --policy /tmp/edited.json --wait'
run "openshell sandbox exec -n life -- curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 https://example.com"
say "Roll back to revision 2 as a new revision"
run 'openshell policy list life'
run "openshell policy get life --rev 2 --base --output json | jq -e '.policy' > /tmp/rev2.json && openshell policy set life --policy /tmp/rev2.json --wait"
run "openshell sandbox exec -n life -- curl -s -o /dev/null -w '%{http_code}\n' https://example.com"
say "A global policy overrides every sandbox"
run 'openshell policy set --global --policy labs/07-policy-lifecycle/global-policy.yaml --yes'
run "sleep 12; openshell sandbox exec -n life -- curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 https://example.com"
run 'openshell policy update life --rule-name x --binary /usr/bin/curl --add-endpoint example.com:443 --wait'
run 'openshell policy delete --global --yes'
run "sleep 12; openshell sandbox exec -n life -- curl -s -o /dev/null -w '%{http_code}\n' https://example.com"
run 'openshell sandbox delete life'
