#!/usr/bin/env bash
# Lab 15 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 15 — The Python SDK"
run_quiet 'openshell sandbox template delete training-tools'
run 'python3 -m venv /tmp/lab15-venv && /tmp/lab15-venv/bin/pip install -q openshell==0.1.4 && /tmp/lab15-venv/bin/pip show openshell | head -2'
run 'openshell sandbox template create training-tools --image openshell-training/tools:0.1.4'
run 'cat labs/15-python-sdk/sdk_demo.py'
run '/tmp/lab15-venv/bin/python labs/15-python-sdk/sdk_demo.py training-tools sdk-demo'
run 'openshell sandbox template delete training-tools'
