#!/usr/bin/env bash
# Lab 14 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 14 — Observability"
run_quiet 'openshell sandbox delete obs'
run 'openshell sandbox create --name obs --from openshell-training/tools:0.1.4 --no-auto-providers --detach'
run 'openshell policy update obs --rule-name echo_api --binary /usr/bin/curl --add-endpoint postman-echo.com:443:read-only:rest:enforce --wait'
run "openshell sandbox exec -n obs -- sh -c 'curl -s -o /dev/null https://postman-echo.com/get; curl -s -o /dev/null -X POST https://postman-echo.com/get; curl -s -o /dev/null --max-time 5 https://example.com'"
say "Shorthand OCSF events"
run "sleep 2; openshell logs obs --since 5m --source sandbox | grep -E 'NET:|HTTP:'"
run "openshell logs obs --since 1h --source sandbox | grep DENIED | grep -oE '(NET|HTTP):[A-Z]+ .*' | sort | uniq -c"
say "Full OCSF JSON from the supervisor container"
run 'openshell settings set obs --key ocsf_json_enabled --value true'
run "sleep 12; openshell sandbox exec -n obs -- curl -s -o /dev/null --max-time 5 https://example.com"
run "SUP=\$(docker ps --format '{{.Names}}' | grep -- '--obs-.*-supervisor\$'); docker logs --since 1m \"\$SUP\" 2>&1 | grep ' OCSF-JSON ' | grep '\"class_uid\":4001' | tail -1 | sed 's/.* OCSF-JSON //' | jq '{class_uid, class_name, activity_name, severity, action, dst_endpoint}'"
run 'openshell sandbox delete obs'
