#!/usr/bin/env bash
# Checks that this host can run OpenShell sandboxes before you install it.
# Prints one line per requirement and exits non-zero if any check fails.
set -u

fail=0
ok()   { printf '  [ok]   %s\n' "$*"; }
bad()  { printf '  [FAIL] %s\n' "$*"; fail=1; }
warn() { printf '  [warn] %s\n' "$*"; }

echo "OpenShell host check"

if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  if [[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]]; then
    ok "OS: $PRETTY_NAME"
  else
    warn "OS: ${PRETTY_NAME:-unknown} (the labs are written for Ubuntu 24.04)"
  fi
fi

arch="$(uname -m)"
case "$arch" in
  x86_64 | aarch64) ok "architecture: $arch" ;;
  *) bad "architecture: $arch (OpenShell supports x86_64 and aarch64)" ;;
esac

# Landlock ABI 3 arrived in Linux 6.2.
kernel="$(uname -r)"
major="${kernel%%.*}"
rest="${kernel#*.}"
minor="${rest%%.*}"
if ((major > 6 || (major == 6 && minor >= 2))); then
  ok "kernel: $kernel (>= 6.2 for Landlock ABI 3)"
else
  bad "kernel: $kernel (need 6.2 or newer for Landlock ABI 3)"
fi

if grep -qw landlock /sys/kernel/security/lsm 2>/dev/null; then
  ok "Landlock LSM is enabled"
else
  bad "Landlock LSM is not in /sys/kernel/security/lsm"
fi

if [[ "$(stat -fc %T /sys/fs/cgroup 2>/dev/null)" == cgroup2fs ]]; then
  ok "cgroups v2"
else
  warn "cgroups v2 not detected (required for Podman, recommended for Docker)"
fi

if command -v docker >/dev/null 2>&1; then
  if dv="$(docker version --format '{{.Server.Version}}' 2>/dev/null)"; then
    if [[ "${dv%%.*}" -ge 28 ]]; then
      ok "Docker Engine $dv (>= 28.0)"
    else
      bad "Docker Engine $dv (need 28.0 or newer)"
    fi
  else
    bad "docker is installed but the daemon is not reachable as $USER (are you in the docker group? log out and back in after adding)"
  fi
else
  bad "docker is not installed (see labs/00-prepare-ubuntu)"
fi

for tool in curl git jq; do
  if command -v "$tool" >/dev/null 2>&1; then ok "$tool"; else bad "$tool is missing (sudo apt install $tool)"; fi
done

if command -v bats >/dev/null 2>&1; then
  ok "bats $(bats --version | awk '{print $2}') (lab tests)"
else
  warn "bats is missing; install it to run the lab tests (sudo apt install bats)"
fi

if [[ -c /dev/kvm ]]; then
  ok "/dev/kvm present (optional MicroVM runtime)"
else
  warn "/dev/kvm not present (only needed for the optional MicroVM runtime)"
fi

if ((fail)); then
  echo "Some checks failed. Fix them before installing OpenShell."
  exit 1
fi
echo "Host is ready for OpenShell."
