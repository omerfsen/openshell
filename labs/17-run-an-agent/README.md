# Lab 17 — Capstone: run a real AI agent

**Goal:** put everything together. Run the **OpenCode** coding agent in a sandbox, give it an
inference API key it can never read, start from deny-all, and grant access as it asks.
**Time:** ~30 minutes. **Prerequisite:** Labs 04, 08, and 10.
**You need:** a free [OpenRouter](https://openrouter.ai) account and API key. The model used
below is a free model, so no credits are required.

## Concepts recap

| Piece | Lab | Role here |
|---|---|---|
| Agent image | 03 | `ghcr.io/anomalyco/opencode:1.19.3` (Alpine, `opencode` at `/usr/local/bin/opencode`, no `USER`, so it runs as UID 1000) |
| Provider profile | 08 | [`openrouter-training.yaml`](openrouter-training.yaml): `OPENROUTER_API_KEY` as a bearer token, only to `openrouter.ai`, only for `opencode` and `curl` |
| Default-deny + advisor | 04, 10 | Every other host the agent tries becomes a pending proposal you review |
| Logs | 14 | Audit what the agent did |

The profile is adapted from NVIDIA's
[`providers/openrouter.yaml`](https://github.com/NVIDIA/OpenShell/blob/v0.1.4/providers/openrouter.yaml).
Read the header of any upstream profile before you import it: it names the binaries and image
layout it assumes.

## 1. Import the profile and store your key

```shell
openshell profile import -f labs/17-run-an-agent/openrouter-training.yaml

read -rs OPENROUTER_API_KEY && export OPENROUTER_API_KEY     # paste your key, press Enter
openshell provider create --name openrouter --type openrouter-training --from-existing
unset OPENROUTER_API_KEY
```

`--from-existing` reads the variable from your shell, so the key never appears in your
command history or process list. From now on it lives only in the gateway's credential store.

## 2. Prove the credential path with curl (no agent yet)

```shell
openshell sandbox create --name agent-check --from openshell-training/tools:0.1.4 \
  --provider openrouter --detach
openshell sandbox exec -n agent-check -- sh -c 'echo "$OPENROUTER_API_KEY"'      # a placeholder
openshell sandbox exec -n agent-check -- sh -c \
  'curl -s -H "Authorization: Bearer $OPENROUTER_API_KEY" https://openrouter.ai/api/v1/key | jq .'
openshell sandbox delete agent-check
```

With a real key, the last call returns your key's metadata (label, limits, usage). The
program sent only the placeholder.

## 3. Run the agent

```shell
docker pull ghcr.io/anomalyco/opencode:1.19.3
openshell sandbox create --name agent \
  --from ghcr.io/anomalyco/opencode:1.19.3 \
  --provider openrouter \
  -- opencode -m openrouter/nvidia/nemotron-3.5-lightning:free
```

You are now in OpenCode's terminal UI, inside the sandbox. Ask it something that needs
tools, for example:

> Create a Python script `fib.py` that prints the first 20 Fibonacci numbers, then run it.

For a non-interactive smoke test:

```shell
openshell sandbox create --name agent-run --from ghcr.io/anomalyco/opencode:1.19.3 \
  --provider openrouter --no-keep --no-tty -- \
  opencode run -m openrouter/nvidia/nemotron-3.5-lightning:free 'Reply with exactly: OK'
```

## 4. Watch it hit the boundary, then grant access

In a second terminal on the host:

```shell
openshell logs agent --tail --source sandbox | grep -E 'NET:|HTTP:'
```

The provider rule allows `opencode` to reach `openrouter.ai`. Anything else the agent tries,
such as fetching a web page, installing a package, or calling another API, is **denied and
drafted as a proposal**:

```shell
openshell rule get agent --status pending
openshell rule approve agent --chunk-id <id>                              # if you agree
openshell rule reject  agent --chunk-id <id> --reason "Not for this task" # if you don't
```

Approved rules hot-reload. The agent retries and continues. For an agent that should write
its own narrow proposals, enable the advisor before starting it:
`openshell settings set --global --key agent_policy_proposals_enabled --value true --yes`.
The sandbox then gets `/AGENTS.md` and a skill that tell the agent how to use
`http://policy.local` (Lab 10).

## 5. Things to try

- Ask the agent to `cat /etc/shadow`, `ls /home`, or `curl https://example.com`. Landlock and
  the network policy stop it, and the log records each attempt.
- Ask it to print `$OPENROUTER_API_KEY`. It gets the placeholder.
- Export the effective policy and prove it against your boundary (Lab 11).
- Detach with `Ctrl-P Ctrl-Q`, then `openshell sandbox connect agent` to reattach.

## 6. Other agents

The same pattern works for any agent you can put in an image. NVIDIA ships profiles for
`claude-code`, `codex`, `copilot`, `cursor`, `anthropic`, `openai`, `nvidia`, and more in
[`providers/`](https://github.com/NVIDIA/OpenShell/tree/v0.1.4/providers). For example,
Claude Code with an Anthropic key:

```shell
openshell profile import --url https://raw.githubusercontent.com/NVIDIA/OpenShell/v0.1.4/providers/claude-code.yaml
openshell provider create --name claude --type claude-code --from-existing   # reads ANTHROPIC_API_KEY
openshell sandbox create --name claude --from <your-image-with-claude> --provider claude -- claude
```

Check the profile's `binaries` against the paths in your image first (Lab 04).

## 7. Clean up

```shell
openshell sandbox delete agent
openshell provider delete openrouter
openshell profile delete openrouter-training
```

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=17          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=17     # asciinema
labs/17-run-an-agent/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/17-run-an-agent/test.bats
```

The tests check the image, the profile, and the credential path with a **fake** key (an
`openrouter.ai` 401 proves the request got through policy). The live agent test runs only when
`OPENROUTER_API_KEY` is set in the shell that runs `bats`.

**Next:** [Lab 18 — Clean up, upgrade, uninstall](../18-cleanup/README.md)
