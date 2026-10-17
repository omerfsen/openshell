# Self-playing terminal walkthroughs for the lab solutions.
#
# A solution script sources this file and calls:
#   say  "text"     print a narration line
#   run  'command'  type the command at human speed, then execute it for real
#   run_quiet 'cmd' type and execute, hiding output (setup noise)
#   pause           wait between steps
#
# Environment:
#   PAUSE=<seconds>   delay between steps (default 1.5; 0 = no waiting)
#   TYPE_SPEED=<cps>  characters per second while typing (default 40; 0 = instant)
#   INTERACTIVE=1     wait for Enter before each command instead of sleeping
#
# Record a solution as an asciinema cast:
#   asciinema rec -c labs/05-l7-rest-rules/solution.sh labs/05-l7-rest-rules/solution.cast

PAUSE="${PAUSE:-1.5}"
TYPE_SPEED="${TYPE_SPEED:-40}"
INTERACTIVE="${INTERACTIVE:-0}"

_bold=$'\033[1m' _dim=$'\033[2m' _cyan=$'\033[36m' _green=$'\033[32m' _reset=$'\033[0m'

pause() {
  if [[ "$INTERACTIVE" == 1 ]]; then
    read -r -s -p "" </dev/tty
  elif [[ "$PAUSE" != 0 ]]; then
    sleep "$PAUSE"
  fi
}

_type() {
  local text="$1" i delay
  if [[ "$TYPE_SPEED" == 0 ]]; then
    printf '%s' "$text"
    return
  fi
  delay="$(awk -v c="$TYPE_SPEED" 'BEGIN { printf "%.3f", 1 / c }')"
  for ((i = 0; i < ${#text}; i++)); do
    printf '%s' "${text:i:1}"
    sleep "$delay"
  done
}

say() {
  printf '\n%s# %s%s\n' "$_cyan" "$*" "$_reset"
}

run() {
  printf '%s$ %s' "$_green" "$_reset$_bold"
  _type "$1"
  printf '%s\n' "$_reset"
  pause
  bash -c "$1"
  local rc=$?
  ((rc == 0)) || printf '%s[exit %d]%s\n' "$_dim" "$rc" "$_reset"
  pause
  return 0
}

run_quiet() {
  printf '%s$ %s' "$_green" "$_reset$_bold"
  _type "$1"
  printf '%s\n' "$_reset"
  bash -c "$1" >/dev/null 2>&1 || true
}

# Solutions run from the repository root so relative paths in commands work.
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
