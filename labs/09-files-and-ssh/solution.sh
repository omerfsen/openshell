#!/usr/bin/env bash
# Lab 09 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 09 — Files, SSH, and editors"
run_quiet 'openshell sandbox delete files'
run 'mkdir -p labs/09-files-and-ssh/sample-project/build && echo junk > labs/09-files-and-ssh/sample-project/build/artifact.bin && echo junk > labs/09-files-and-ssh/sample-project/debug.log'
run 'openshell sandbox create --name files --from openshell-training/tools:0.1.4 --no-auto-providers --detach'
say "Upload respects .gitignore"
run 'openshell sandbox upload files labs/09-files-and-ssh/sample-project'
run 'openshell sandbox exec -n files -- find sample-project -type f'
run 'openshell sandbox exec -n files -- python3 sample-project/src/app.py'
say "Download is confined to the working directory"
run "openshell sandbox exec -n files -- sh -c 'mkdir -p out && date > out/report.txt'"
run 'openshell sandbox download files out /tmp/lab09-out && cat /tmp/lab09-out/report.txt'
run 'openshell sandbox download files /etc/passwd /tmp/lab09-passwd'
say "An SSH config block for any SSH client"
run 'openshell sandbox ssh-config files'
say "Clean up"
run 'openshell sandbox delete files; rm -rf /tmp/lab09-out labs/09-files-and-ssh/sample-project/build labs/09-files-and-ssh/sample-project/debug.log'
