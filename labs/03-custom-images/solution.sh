#!/usr/bin/env bash
# Lab 03 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 03 — Bring your own image"
run_quiet 'openshell sandbox delete tools baked rooty'
run 'cat images/tools/Dockerfile'
run 'docker build -q -t openshell-training/tools:0.1.4 images/tools'
run 'openshell sandbox create --name tools --from openshell-training/tools:0.1.4 --no-auto-providers --detach'
run "openshell sandbox exec -n tools -- sh -c 'id; command -v curl python3 git'"
run 'openshell sandbox exec -n tools -- readlink -f /usr/bin/python3 /usr/bin/nc'
say "Images that run as root are rejected"
run "printf 'FROM ubuntu:24.04\nUSER root\n' | docker build -q -t openshell-training/rootimg:test -"
run 'openshell sandbox create --name rooty --from openshell-training/rootimg:test --no-auto-providers --detach'
run_quiet 'openshell sandbox delete rooty'
say "A policy baked into the image at /etc/openshell/policy.yaml"
run 'cat images/baked-policy/policy.yaml'
run 'docker build -q -t openshell-training/baked-policy:0.1.4 images/baked-policy'
run 'openshell sandbox create --name baked --from openshell-training/baked-policy:0.1.4 --no-auto-providers --detach'
run "openshell sandbox exec -n baked -- curl -s https://postman-echo.com/get | jq -c '{url}'"
run "openshell sandbox exec -n baked -- curl -s -o /dev/null -w '/headers -> %{http_code}\n' https://postman-echo.com/headers"
say "Clean up"
run 'openshell sandbox delete tools baked'
