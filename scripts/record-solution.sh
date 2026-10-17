#!/usr/bin/env bash
# Record a lab's solution.sh once and write two replayable formats:
#   solution.log + solution.timing   util-linux script/scriptreplay (preinstalled)
#   solution.cast                    asciinema v2 (asciinema play, web player)
#
# Usage: scripts/record-solution.sh labs/05-l7-rest-rules
set -euo pipefail

lab="${1:?usage: $0 labs/<lab-dir>}"
lab="${lab%/}"
[[ -x "$lab/solution.sh" ]] || { echo "no executable $lab/solution.sh" >&2; exit 1; }

cols=110 rows=32
log="$lab/solution.log" timing="$lab/solution.timing" cast="$lab/solution.cast"

# A fixed terminal size keeps replays readable everywhere.
COLUMNS=$cols LINES=$rows script --quiet --return \
  --log-out "$log" --log-timing "$timing" \
  --command "stty cols $cols rows $rows 2>/dev/null; $lab/solution.sh"

# Drop the "Script started/done" header and footer lines from the log so a
# replay starts with the walkthrough itself.
python3 - "$log" "$timing" "$cast" "$cols" "$rows" "$lab" <<'PY'
import json, sys, time

log_path, timing_path, cast_path, cols, rows, lab = sys.argv[1:]
data = open(log_path, "rb").read()
header_end = data.find(b"\n") + 1 if data.startswith(b"Script started") else 0

events, offset, clock = [], header_end, 0.0
for line in open(timing_path):
    delay, nbytes = line.split()
    clock += float(delay)
    chunk = data[offset:offset + int(nbytes)]
    offset += int(nbytes)
    if chunk:
        events.append([round(clock, 6), "o", chunk.decode("utf-8", "replace")])

header = {"version": 2, "width": int(cols), "height": int(rows),
          "timestamp": int(time.time()), "title": f"OpenShell training: {lab}",
          "env": {"TERM": "xterm-256color", "SHELL": "/bin/bash"}}
with open(cast_path, "w") as out:
    out.write(json.dumps(header) + "\n")
    for event in events:
        out.write(json.dumps(event) + "\n")
PY

echo "wrote $log, $timing, $cast"
echo "replay:  scriptreplay --timing $timing $log"
echo "     or: asciinema play $cast"
