#!/usr/bin/env bash
# Lab 19 solution: replays the lab against your gateway (already upgraded to 0.1.6).
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 19 — What's new in 0.1.6 (the host is already upgraded)"
run_quiet 'openshell sandbox delete lab19-new lab19-cfg'
run 'openshell --version; openshell status | grep -E "Status|Authentication|Version"'
run "journalctl --user -u openshell-gateway -b | grep -o 'mTLS user authentication enabled' | tail -1"

say "A request with no credential is refused, and audited"
run "curl -sk --http2 -i -X POST -H 'content-type: application/grpc' -H 'te: trailers' --data-binary @/dev/null https://127.0.0.1:17670/openshell.v1.OpenShell/ListSandboxes | grep -iE 'grpc-(status|message)'"
run "journalctl --user -u openshell-gateway --since -1min | grep -o 'OCSF AUTH:LOGON.*DENIED.*' | tail -1"

say "--env-from and --annotation"
run 'export LAB19_TOKEN=demo-value-19; openshell sandbox create --name lab19-new --from openshell-training/tools:0.1.4 --no-auto-providers --detach --env-from LAB19_TOKEN --env-from API_TOKEN=LAB19_TOKEN --annotation team=platform --annotation "note=has spaces / and =" | tail -1'
run "openshell sandbox exec -n lab19-new --no-login-shell -- sh -c 'echo \"LAB19_TOKEN=\$LAB19_TOKEN API_TOKEN=\$API_TOKEN\"'"
run 'openshell sandbox create --name lab19-bad --from openshell-training/tools:0.1.4 --no-auto-providers --detach --env-from NOPE_NOT_SET'
run "openshell sandbox get lab19-new | sed -n '/Annotations/,/Conditions/p' | grep -v internal.openshell"
run 'openshell sandbox create --name lab19-bad --from openshell-training/tools:0.1.4 --no-auto-providers --detach --annotation internal.openshell.ai/x=1'

say "Suspend needs a driver that supports it; Docker does not"
run 'openshell sandbox suspend lab19-new'

say "Policy delivery: poll (default) first"
run 'openshell sandbox create --name lab19-cfg --from openshell-training/tools:0.1.4 --policy labs/07-policy-lifecycle/policy.yaml --no-auto-providers --detach | tail -1'
run 'time openshell policy update lab19-cfg --rule-name r1 --binary /usr/bin/curl --add-endpoint example1.com:443 --wait | tail -1'

say "Now push: one line in gateway.toml"
run 'grep config_delivery_mode labs/19-whats-new-0.1.6/gateway-push.toml'
run 'openshell-gateway config preflight --path labs/19-whats-new-0.1.6/gateway-push.toml && echo valid'
run_quiet 'cp ~/.config/openshell/gateway.toml ~/.config/openshell/gateway.toml.before-lab19 2>/dev/null; true'
run 'cp labs/19-whats-new-0.1.6/gateway-push.toml ~/.config/openshell/gateway.toml && systemctl --user restart openshell-gateway'
run 'for i in $(seq 40); do openshell sandbox list 2>/dev/null | grep -q "lab19-cfg.*Ready" && break; sleep 1; done; openshell sandbox list'
run 'time openshell policy update lab19-cfg --rule-name r2 --binary /usr/bin/curl --add-endpoint example2.com:443 --wait | tail -1'

say "Clean up: back to polling"
run 'openshell sandbox delete lab19-new lab19-cfg'
run 'if [ -f ~/.config/openshell/gateway.toml.before-lab19 ]; then mv ~/.config/openshell/gateway.toml.before-lab19 ~/.config/openshell/gateway.toml; else rm ~/.config/openshell/gateway.toml; fi; systemctl --user restart openshell-gateway'
run 'for i in $(seq 20); do openshell status 2>/dev/null | grep -q Connected && break; sleep 1; done; openshell status | grep Status'
