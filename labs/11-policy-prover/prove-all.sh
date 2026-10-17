#!/usr/bin/env bash
# CI gate: prove every policy file against a boundary. Only `within_boundary`
# passes; exceeds_boundary, unsupported, inconclusive, and error all fail.
#
# Usage: prove-all.sh <boundary.yaml> <policy.yaml>...
set -uo pipefail

boundary="${1:?usage: $0 <boundary.yaml> <policy.yaml>...}"
shift

failed=0
for policy in "$@"; do
  report="$(openshell-prover check "$policy" --boundary "$boundary" --output json)"
  result="$(jq -r .result <<<"$report")"
  if [[ "$result" == within_boundary ]]; then
    printf 'PASS  %s\n' "$policy"
  else
    failed=1
    detail="$(jq -r '.reason // (.counterexample | tostring)' <<<"$report")"
    printf 'FAIL  %s  [%s] %s\n' "$policy" "$result" "$detail"
  fi
done
exit "$failed"
