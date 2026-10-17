#!/usr/bin/env bash
# Lab 00 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 00 — Prepare a fresh Ubuntu 24.04 host"
run '. /etc/os-release; echo "$PRETTY_NAME"; uname -r'
run 'cat /sys/kernel/security/lsm; echo'
run "docker version --format 'Docker Engine {{.Server.Version}}'"
run 'id -nG | tr " " "\n" | grep -x docker'
say "The course's host check"
run 'scripts/check-host.sh'
