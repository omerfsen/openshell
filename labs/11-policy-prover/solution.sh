#!/usr/bin/env bash
# Lab 11 solution: replays the lab against your gateway.
source "$(dirname "$0")/../../scripts/autoplay.sh"

say "Lab 11 — The policy prover"
run 'cd labs/11-policy-prover && cat boundary-fs.yaml candidates/fs-write-tmp.yaml'
run 'cd labs/11-policy-prover && openshell-prover check candidates/fs-read-usr.yaml --boundary boundary-fs.yaml'
run 'cd labs/11-policy-prover && openshell-prover check candidates/fs-write-tmp.yaml --boundary boundary-fs.yaml'
say "Network proofs against the training boundary"
run 'cat labs/11-policy-prover/boundary.yaml'
run 'cd labs/11-policy-prover && openshell-prover check candidates/narrow.yaml --boundary boundary.yaml'
run 'cd labs/11-policy-prover && openshell-prover check candidates/extra-binary.yaml --boundary boundary.yaml'
run 'cd labs/11-policy-prover && openshell-prover check candidates/write-method.yaml --boundary boundary.yaml --output json | jq .counterexample'
run 'cd labs/11-policy-prover && openshell-prover check candidates/graphql.yaml --boundary boundary.yaml'
say "The CI gate"
run 'cd labs/11-policy-prover && ./prove-all.sh boundary.yaml candidates/narrow.yaml candidates/extra-binary.yaml candidates/graphql.yaml'
