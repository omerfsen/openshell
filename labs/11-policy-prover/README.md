# Lab 11 — The policy prover: formal verification for policies

**Goal:** prove that a policy grants **no more** than an approved boundary, read
counterexamples, and wire the check into CI so an over-broad policy can't be merged.
**Time:** ~20 minutes. **Prerequisite:** [Lab 10](../10-policy-advisor/README.md).

## Concepts

`openshell-prover` encodes two policies as logic and asks an **SMT solver** whether there is
*any* request the candidate allows that the boundary does not. If one exists, it prints that
request as a **counterexample**. This is not linting or pattern matching. It is a proof over
everything the model covers:

`coverage: domains=filesystem,network_l4,network_rest,process,landlock`

It runs offline. It needs no gateway and never applies anything, which makes it a good fit
for CI and for a parent agent checking a policy it wrote for a sub-agent.

| Result | Exit | Meaning |
|---|---|---|
| `within_boundary` | 0 | Nothing beyond the boundary in the modeled domains. **The only pass.** |
| `exceeds_boundary` | 1 | The candidate allows more. A counterexample shows one case. |
| `error` | 2 | Missing file, invalid policy, … |
| `unsupported` | 3 | The policy uses something the model cannot check (GraphQL, MCP, WebSocket, audit-mode REST, path comparisons that depend on the image). It refuses rather than guesses. |
| `inconclusive` | 3 | Solver timeout or resource limit |

The gateway uses the same engine for the advisor's **proposal risk check** (Lab 10). That is
a different question ("does this rule add risky reach compared to now?"), so passing one does
not imply passing the other.

## 1. A filesystem proof

```shell
cd labs/11-policy-prover
cat boundary-fs.yaml                 # read /usr and /etc, write nothing
openshell-prover check candidates/fs-read-usr.yaml --boundary boundary-fs.yaml
```

```text
result: within_boundary
coverage: domains=filesystem,network_l4,network_rest,process,landlock
```

```shell
openshell-prover check candidates/fs-write-tmp.yaml --boundary boundary-fs.yaml; echo "exit $?"
```

```text
result: exceeds_boundary
coverage: domains=filesystem,network_l4,network_rest,process,landlock
counterexample: filesystem write /tmp
exit 1
```

## 2. Network proofs

[`boundary.yaml`](boundary.yaml) is the most any training sandbox may have: the default
filesystem plus **read-only** postman-echo.com access **for curl only**.

```shell
openshell-prover check candidates/narrow.yaml       --boundary boundary.yaml   # within: GET /get only
openshell-prover check candidates/extra-binary.yaml --boundary boundary.yaml   # exceeds
openshell-prover check candidates/write-method.yaml --boundary boundary.yaml   # exceeds
openshell-prover check candidates/graphql.yaml      --boundary boundary.yaml   # unsupported
```

The counterexamples name the exact request that breaks the boundary:

```text
counterexample: network binary=/ ancestor_binary=/usr/bin/python3.12 ... host=postman-echo.com:443 ... protocol=rest method=GET path=/
counterexample: network ... host=postman-echo.com:443 ... protocol=rest method=POST path=/
reason: candidate policy rule 'countries_graphql' uses protocol 'graphql'; only L4 TCP and REST are modeled
```

The prover checks every policy both **with and without** binary-identity enforcement,
because a runtime may turn it off. That is why the first counterexample says
`binary_identity_required=true`.

## 3. Prove a live sandbox's policy

Export the **effective** policy (including provider rules) and prove it:

```shell
openshell sandbox create --name prove --from openshell-training/tools:0.1.4 --no-auto-providers --detach
openshell policy update prove --rule-name echo_read --binary /usr/bin/curl \
  --add-endpoint postman-echo.com:443:read-only:rest:enforce --wait
openshell sandbox get prove --policy-only > /tmp/live.yaml
openshell-prover check /tmp/live.yaml --boundary boundary.yaml        # within_boundary

# Approve something broader, the way an advisor proposal might:
openshell policy update prove --rule-name py --binary /usr/bin/python3.12 \
  --add-endpoint postman-echo.com:443:read-only:rest:enforce --wait
openshell sandbox get prove --policy-only > /tmp/live.yaml
openshell-prover check /tmp/live.yaml --boundary boundary.yaml        # exceeds_boundary
openshell sandbox delete prove
```

## 4. Gate CI on it

[`prove-all.sh`](prove-all.sh) proves many files and fails unless **every** one is
`within_boundary`. It reads `--output json` and the `result` field, never the text:

```shell
./prove-all.sh boundary.yaml candidates/narrow.yaml candidates/extra-binary.yaml candidates/graphql.yaml
```

```text
PASS  candidates/narrow.yaml
FAIL  candidates/extra-binary.yaml  [exceeds_boundary] {"domain":"network",...}
FAIL  candidates/graphql.yaml  [unsupported] candidate policy rule 'countries_graphql' uses protocol 'graphql'; ...
```

[`github-actions-example.yml`](github-actions-example.yml) installs the standalone 0.1.4
prover from the GitHub release (checksum-verified) and runs the same gate on every pull
request that touches `policies/`.

## Limits worth knowing

- Filesystem paths are compared **path by path**: `/tmp/cache` under a boundary of `/tmp` is
  `unsupported` (a symlink in the image could point elsewhere).
- An exact binary under a boundary glob (`/usr/bin/curl` vs `/usr/bin/*`) is `unsupported`.
  Use the same exact paths in both.
- REST endpoints must use `enforcement: enforce`. Audit mode does not block, so it can't be
  proven.
- A pass means "no more than the boundary", not "minimal" or "safe for this task".

## Exercises

1. Write a candidate that allows `GET /repos/**` with a `deny_rules` entry and prove it.
2. Add `--timeout 1` to a check. When could `inconclusive` appear in practice?

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=11          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=11     # asciinema
labs/11-policy-prover/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/11-policy-prover/test.bats
```

**Next:** [Lab 12 — Ports, forwarding, and exposed services](../12-ports-and-services/README.md)
