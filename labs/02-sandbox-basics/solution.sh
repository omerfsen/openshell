#!/usr/bin/env bash
# Lab 02 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 02 — Sandbox basics"
run_quiet 'openshell sandbox delete basics once'
run 'openshell sandbox create --name basics --no-auto-providers --detach'
run 'openshell sandbox list'
say "One-shot commands; the exit code comes back"
run 'openshell sandbox exec -n basics -- id'
run "openshell sandbox exec -n basics -- sh -c 'touch ~/hello && echo working dir is writable; echo x > /etc/x'"
run 'openshell sandbox exec -n basics -- sh -c "command -v curl || echo no curl in the default image"'
run "openshell sandbox exec -n basics -- sh -c 'exit 3'; echo \"exit code: \$?\""
run 'echo "piped stdin" | openshell sandbox exec -n basics -- cat'
run "openshell sandbox exec -n basics --env GREETING=merhaba -- sh -c 'echo \$GREETING'"
say "Inspect"
run "openshell sandbox get basics | sed -n '1,/^Policy:/p'"
say "Stop keeps the workspace; start brings it back"
run 'openshell sandbox stop basics && openshell sandbox list'
run 'openshell sandbox start basics && openshell sandbox exec -n basics -- sh -c "ls ~"'
say "Throwaway sandbox"
run "openshell sandbox create --name once --no-auto-providers --no-keep --no-tty -- sh -c 'echo hello from \$(hostname) as \$(id -un)'"
say "Clean up"
run 'openshell sandbox delete basics'
