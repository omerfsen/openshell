#!/usr/bin/env bash
# Lab 12 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 12 — Ports, forwarding, and exposed services"
run_quiet 'openshell sandbox delete web'
run 'openshell sandbox create --name web --from openshell-training/tools:0.1.4 --no-auto-providers --detach -- python3 -m http.server 8000 --bind 127.0.0.1 --directory /tmp'
run "sleep 2; openshell sandbox exec -n web -- sh -c 'echo \"<h1>hello from a sandbox</h1>\" > /tmp/index.html'"
say "SSH port forward"
run 'openshell forward start 8000 web -d < /dev/null'
run 'openshell forward list; curl -s http://127.0.0.1:8000/'
run 'openshell forward stop 8000 web'
say "gRPC service forward"
run '(openshell forward service web --target-port 8000 --local 18000 & sleep 3; curl -s http://127.0.0.1:18000/; kill $!)'
say "Gateway-managed service URL"
run 'openshell service expose web 8000'
run 'curl -s http://default--web.openshell.localhost:17670/'
run 'openshell service list'
run 'openshell service delete web; openshell sandbox delete web'
