#!/usr/bin/env bash
# Lab 18 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 18 — Clean up"
run 'scripts/cleanup.sh'
run 'openshell sandbox list; openshell provider list; openshell profile list'
run 'openshell status'
