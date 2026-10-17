#!/usr/bin/env bash
# Lab 08 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 08 — Providers: credentials the agent never sees"
run_quiet 'openshell sandbox delete cred; openshell provider delete echo; openshell profile delete echo-api'
run 'cat labs/08-providers-and-credentials/echo-api.yaml'
run 'openshell profile lint -f labs/08-providers-and-credentials/echo-api.yaml && openshell profile import -f labs/08-providers-and-credentials/echo-api.yaml'
run 'openshell provider create --name echo --type echo-api --credential DEMO_API_TOKEN=training-secret-1234'
run 'openshell provider list'
run 'openshell sandbox create --name cred --from openshell-training/tools:0.1.4 --provider echo --detach'
say "Inside the sandbox: only a placeholder"
run "openshell sandbox exec -n cred -- sh -c 'echo \"\$DEMO_API_TOKEN\"'"
say "At the bound endpoint the real secret appears on the wire"
run "openshell sandbox exec -n cred -- sh -c 'curl -s -H \"Authorization: Bearer \$DEMO_API_TOKEN\" https://httpbin.org/headers | jq -r .headers.Authorization'"
say "Try to send it somewhere else"
run 'openshell policy update cred --rule-name other_echo --binary /usr/bin/curl --add-endpoint postman-echo.com:443:read-only:rest:enforce --wait'
run "openshell sandbox exec -n cred -- sh -c 'curl -s -H \"Authorization: Bearer \$DEMO_API_TOKEN\" https://postman-echo.com/headers'; echo"
say "Rotate the secret"
run 'openshell provider update echo --credential DEMO_API_TOKEN=rotated-5678 --wait | tail -2'
run "openshell sandbox exec -n cred -- sh -c 'curl -s -H \"Authorization: Bearer \$DEMO_API_TOKEN\" https://httpbin.org/headers | jq -r .headers.Authorization'"
say "Clean up"
run 'openshell sandbox delete cred && openshell provider delete echo && openshell profile delete echo-api'
