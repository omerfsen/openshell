#!/usr/bin/env bash
# Lab 04 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 04 — Default-deny networking and binary-scoped rules"
run_quiet 'openshell sandbox delete net'
run 'openshell sandbox create --name net --from openshell-training/tools:0.1.4 --no-auto-providers --detach'
say "Everything is denied by default"
run 'openshell sandbox exec -n net -- curl -sS --max-time 8 https://postman-echo.com/get'
run "sleep 2; openshell logs net --since 5m --source sandbox | grep -E 'NET:|HTTP:' | tail -3"
say "Allow one host for one binary"
run 'openshell policy update net --rule-name echo_api --binary /usr/bin/curl --add-endpoint postman-echo.com:443 --wait'
run "openshell sandbox exec -n net -- curl -s https://postman-echo.com/get | jq -c '{url}'"
run "openshell sandbox exec -n net -- python3 -c 'import urllib.request; urllib.request.urlopen(\"https://postman-echo.com/get\")' 2>&1 | tail -1"
run "sleep 2; openshell logs net --since 2m --source sandbox | grep -E 'NET:OPEN' | tail -2"
say "The metadata address can never be allowed; sandbox loopback works"
run 'openshell policy update net --rule-name meta --binary /usr/bin/curl --add-endpoint 169.254.169.254:80 --wait'
run "openshell sandbox exec -n net -- sh -c 'python3 -m http.server 9000 --bind 127.0.0.1 >/dev/null 2>&1 & sleep 1; curl -s -o /dev/null -w \"loopback %{http_code}\n\" http://127.0.0.1:9000/'"
say "Remove the rule again"
run 'openshell policy update net --remove-rule echo_api --wait'
run 'openshell policy list net'
run 'openshell sandbox delete net'
