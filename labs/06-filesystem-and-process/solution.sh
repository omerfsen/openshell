#!/usr/bin/env bash
# Lab 06 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 06 — Filesystem and process controls"
run_quiet 'openshell sandbox delete fs'
run 'cat labs/06-filesystem-and-process/policy.yaml'
run 'openshell sandbox create --name fs --from openshell-training/tools:0.1.4 --policy labs/06-filesystem-and-process/policy.yaml --no-auto-providers --detach'

say "Probe the Landlock boundary"
run "openshell sandbox exec -n fs -- sh -c 'id; echo a > ~/w && echo home: writable; echo b > /tmp/w && echo tmp: writable; echo c > /etc/x || echo etc: read-only'"
run 'openshell sandbox exec -n fs -- ls /opt'
run 'openshell sandbox exec -n fs -- ls /.openshell'

say "Adding a path on a live sandbox is saved but not applied"
run "sed 's#    - /dev/urandom#    - /dev/urandom\n    - /opt#' labs/06-filesystem-and-process/policy.yaml > /tmp/fs-add.yaml"
run 'openshell policy set fs --policy /tmp/fs-add.yaml --wait'
run 'openshell sandbox exec -n fs -- ls /opt'

say "Removing a path or changing Landlock is rejected"
run 'grep -v /dev/urandom labs/06-filesystem-and-process/policy.yaml > /tmp/fs-remove.yaml'
run 'openshell policy set fs --policy /tmp/fs-remove.yaml --wait'

say "Recreate the sandbox to apply startup sections"
run 'openshell sandbox delete fs'
run 'sleep 2; openshell sandbox create --name fs --from openshell-training/tools:0.1.4 --policy /tmp/fs-add.yaml --no-auto-providers --detach'
run 'openshell sandbox exec -n fs -- ls /opt && echo "/opt is visible now"'

say "Clean up"
run 'openshell sandbox delete fs'
