# Lab 10 — The policy advisor: let the agent ask for access

**Goal:** grow a policy from real denials instead of guessing it up front. Review rules that
OpenShell drafts, rules the **agent itself** proposes, and turn on automatic approval for
low-risk requests.
**Time:** ~25 minutes. **Prerequisite:** [Lab 09](../09-files-and-ssh/README.md).

## Concepts

Writing a perfect policy before an agent runs is hard. The advisor closes the loop:

```text
agent request ─► DENIED ─► proposal (narrow rule) ─► prover risk check ─► you approve/reject
                                                                       └► auto-approve if no risk
approved ─► rule hot-reloads ─► agent retries
```

Proposals come from two places:

1. **Mechanistic drafts.** In *every* sandbox, OpenShell turns a blocked connection into a
   draft "allow binary B to reach host H:port".
2. **Agent-authored proposals.** With `agent_policy_proposals_enabled=true`, the sandbox gets
   a guide (`/etc/openshell/skills/policy_advisor.md`, an agent skill, and `/AGENTS.md`) and a
   local API at **`http://policy.local`** where the agent submits a precise rule (method +
   path) with a reason, then waits for your decision.

Every proposal is run through the **prover's proposal risk check**: does it give a binary new
link-local or metadata reach, send a credential somewhere new, add a new HTTP method where a
credential is used, or open an uninspectable channel to a credentialed host? Any finding, or
a flagged destination (private IPs, wildcards, ports > 49152, database ports), means it
**always** waits for a human, even in auto mode.

## 1. Mechanistic drafts from denials

```shell
openshell sandbox create --name adv --from openshell-training/tools:0.1.4 --no-auto-providers --detach
openshell sandbox exec -n adv -- curl -sS --max-time 8 https://postman-echo.com/get   # denied
sleep 15   # drafts are batched; give it 10-20 seconds
openshell rule get adv --status pending
```

```text
Network Rules:  (version 1, 1 chunk)

  Chunk: 0a84ee0b-59b2-4a32-8911-91a6ffc5bcfe
  Status: pending
  Rule: allow_postman_echo_com_443
  Binary: /usr/bin/curl
  Confidence: 65%
  Rationale: Allow curl to connect to postman-echo.com:443 (HTTPS).
  Prover: prover: no new findings
  Endpoints: postman-echo.com:443 [L7 rest, access=read-only]
  Binaries: /usr/bin/curl
```

Approve it and retry. The blocked request stays blocked, so the program must try again:

```shell
openshell rule approve adv --chunk-id <chunk-id>
sleep 3
openshell sandbox exec -n adv -- curl -s https://postman-echo.com/get; echo
openshell rule history adv
```

Approving rechecks the remaining pending proposals against the new policy, so you can work
through a queue one by one, or run `openshell rule approve-all adv`. That skips
security-flagged ones unless you add `--include-security-flagged`.

## 2. Agent-authored proposals via `policy.local`

Turn the advisor on for the sandbox (it takes effect on the next settings poll, ~10 s):

```shell
openshell settings set adv --key agent_policy_proposals_enabled --value true
sleep 12
openshell sandbox exec -n adv -- curl -s 'http://policy.local/v1/denials?last=3' | jq .
openshell sandbox exec -n adv -- curl -s http://policy.local/v1/policy/current | head -20
```

`policy.local` needs no network rule. It is served by the supervisor and is reachable only
from inside the sandbox. Submit the narrow rule in [`proposal.json`](proposal.json), which
asks for `GET /status/200` only:

```shell
openshell sandbox exec -n adv -- curl -s -X POST -H 'Content-Type: application/json' \
  --data-binary @- http://policy.local/v1/proposals < labs/10-policy-advisor/proposal.json
```

```json
{"status":"submitted","accepted_chunks":1,"rejected_chunks":0,"rejection_reasons":[],
 "accepted_chunk_ids":["10d09d0c-536f-4635-b4e4-5f24892f04bf"]}
```

On the host it shows up with the agent's own rationale:

```shell
openshell rule get adv --status pending
#   Rule: echo_status_read
#   Rationale: Let curl read the status endpoint on postman-echo.com.
#   Endpoints: postman-echo.com:443 [L7 rest, allow GET /status/200]
```

Reject it with a reason. The agent reads the reason back and can try a narrower request:

```shell
openshell rule reject adv --chunk-id <chunk-id> --reason "Not needed for this task."
openshell sandbox exec -n adv -- curl -s http://policy.local/v1/proposals/<chunk-id> | jq '{status, rejection_reason, validation_result}'
```

A real agent calls `GET /v1/proposals/<id>/wait?timeout=300` to block until you decide.
After approval the response says `policy_reloaded: true` and it retries.

## 3. Automatic approval

```shell
openshell sandbox create --name auto --from openshell-training/tools:0.1.4 \
  --no-auto-providers --approval-mode auto --detach
openshell sandbox exec -n auto -- curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 https://example.com   # 000
sleep 10
openshell sandbox exec -n auto -- curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 https://example.com   # 200
openshell rule get auto      # Status: approved
```

The draft for `example.com` had no prover findings and no flags, so OpenShell approved it on
its own. Only use auto mode when you accept that programs in the sandbox may reach **new
public hosts without credentials** without asking you. An admin can force manual review
everywhere with `openshell settings set --global --key proposal_approval_mode --value manual --yes`.

`openshell term` shows pending proposals in the terminal UI too.

## 4. Clean up

```shell
openshell sandbox delete adv auto
```

## Exercises

1. Edit `proposal.json` to ask for `169.254.169.254:80`. What does the submit response say?
2. Attach the Lab 08 provider and propose a new method on `httpbin.org`. Which prover finding
   appears?

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=10          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=10     # asciinema
labs/10-policy-advisor/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/10-policy-advisor/test.bats
```

**Next:** [Lab 11 — The policy prover](../11-policy-prover/README.md)
