#!/usr/bin/env bash
# Lab 05 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 05 — L7 REST rules: allow reads, block writes"
run_quiet 'openshell sandbox delete l7'
run 'openshell sandbox create --name l7 --from openshell-training/tools:0.1.4 --no-auto-providers --detach'

say "Read-only, inspected access to postman-echo.com for curl only"
run 'openshell policy update l7 --rule-name echo_api --binary /usr/bin/curl --add-endpoint postman-echo.com:443:read-only:rest:enforce --wait'
run 'openshell sandbox exec -n l7 -- curl -s https://postman-echo.com/get; echo'

say "A write is answered by the supervisor, not by postman-echo"
run "openshell sandbox exec -n l7 -- curl -s -X POST https://postman-echo.com/post -d '{\"title\":\"oops\"}' | jq ."

say "Allow one extra write, then deny one read path"
run "openshell policy update l7 --rule-name echo_api --binary /usr/bin/curl --add-allow 'postman-echo.com:443:POST:/post' --wait"
run "openshell policy update l7 --rule-name echo_api --binary /usr/bin/curl --add-deny 'postman-echo.com:443:GET:/headers' --wait"
run "openshell sandbox exec -n l7 -- curl -s -o /dev/null -w 'GET /get:     %{http_code}\n' https://postman-echo.com/get"
run "openshell sandbox exec -n l7 -- curl -s -o /dev/null -w 'GET /headers: %{http_code}\n' https://postman-echo.com/headers"

say "Audit mode: violations pass but are logged"
run 'openshell policy update l7 --rule-name httpbin_audit --binary /usr/bin/curl --add-endpoint httpbin.org:443:read-only:rest:audit --wait'
run "openshell sandbox exec -n l7 -- curl -s -o /dev/null -w 'audit POST: %{http_code}\n' -X POST https://httpbin.org/post"
run "sleep 2; openshell logs l7 --since 2m --source sandbox | grep -E 'HTTP:' | tail -4"

say "The resulting base policy"
run "openshell policy get l7 --base | sed -n '/network_policies/,\$p'"

say "Clean up"
run 'openshell sandbox delete l7'
