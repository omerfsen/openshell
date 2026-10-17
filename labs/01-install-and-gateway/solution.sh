#!/usr/bin/env bash
# Lab 01 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 01 — Install OpenShell and meet the gateway"
say "Installed with: curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/v0.1.4/install.sh | OPENSHELL_VERSION=v0.1.4 sh"
run 'openshell --version; openshell-gateway --version; openshell-prover --version'
run 'openshell status'
run 'openshell gateway list'
run 'openshell gateway info'
run 'openshell doctor check'
run 'systemctl --user --no-pager status openshell-gateway | head -5'
say "Preflight a gateway config before restarting the service"
run 'cat labs/01-install-and-gateway/gateway.toml'
run 'openshell-gateway config preflight --path labs/01-install-and-gateway/gateway.toml && echo valid'
run "sed 's/compute_driver = \"docker\"/compute_drivers = [\"docker\"]/' labs/01-install-and-gateway/gateway.toml > /tmp/bad.toml"
run 'openshell-gateway config preflight --path /tmp/bad.toml'
