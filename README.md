# OpenShell Hands-On: a self-paced training

A practical, lab-by-lab course on **[NVIDIA OpenShell](https://github.com/NVIDIA/OpenShell)**,
the open-source runtime that lets autonomous AI agents read files, call APIs, and use
credentials **without** unrestricted access to your data, secrets, or network.

You start from a **fresh Ubuntu 24.04** machine and end by running a real coding agent inside
a sandbox whose every file access, network connection, HTTP request, MCP tool call, and
credential use is governed by a policy you wrote and formally verified.

Every lab has three parts: a document that explains and walks you through it, an automatic
**check** (`bats`) that proves your sandbox behaves as the lab says, and a **solution replay**
you can watch or run.

> **Version.** This course is written and tested against **OpenShell 0.1.4** (stable release
> `v0.1.4`, tagged 2026-10-13, commit `5a7728c30`) with the `openshell==0.1.4` Python SDK, on
> Ubuntu 24.04.4 LTS (kernel 6.8) with Docker Engine 29.9. Lab 01 pins the install to that
> version. OpenShell releases most weeks, so if you use a newer version, expect small
> differences in output.
>
> *Community training material, not an official NVIDIA product.*

The article behind this course: [Giving AI agents a seatbelt via OpenShell](https://www.linkedin.com/pulse/giving-ai-agents-seatbelt-via-openshell-omer-sen-bvjde).

## What OpenShell does, in one picture

```text
  you ──► openshell CLI ──mTLS──► GATEWAY  (control plane: sandboxes, policy, providers, audit)
                                     │
                    compute driver   ▼   (Docker here; also Podman, Kubernetes, MicroVM)
          ┌───────────────────── sandbox boundary ─────────────────────┐
          │  SUPERVISOR (trusted)                                       │──► internet, only where
          │   • decides every connection & HTTP request against policy  │    policy allows, with
          │   • swaps credential placeholders for real secrets          │    real credentials added
          │   ▲ authenticated channel                                   │    only at bound endpoints
          │   ▼                                                         │
          │  WORKLOAD (no network device, non-root, no capabilities)    │
          │   Landlock: only listed paths   seccomp: syscalls mediated  │
          │   your agent ─► sees placeholders, never real keys          │
          └─────────────────────────────────────────────────────────────┘
```

## How to start

1. **Get a machine.** A fresh Ubuntu 24.04 LTS VM: 2 vCPU, 8 GB RAM, 30 GB disk recommended
   (4 GB RAM works). Cloud, Multipass, or bare metal. Details in [Lab 00](labs/00-prepare-ubuntu/README.md).
2. **Clone the course:**
   ```shell
   git clone https://github.com/omerfsen/openshell.git ~/openshell-training
   cd ~/openshell-training
   ```
3. **Follow the labs in order**, starting with [Lab 00](labs/00-prepare-ubuntu/README.md). Each
   lab tells you what it needs and links to the next one.
4. **After each lab, check your work:**
   ```shell
   bats labs/05-l7-rest-rules/test.bats     # or: make test LAB=05
   ```
5. **Stuck?** Watch the solution: `make replay LAB=05`. Or run it live: `make solution LAB=05`.

All commands run from the repository root.

## The labs

| # | Lab | You will learn | OpenShell feature |
|---|---|---|---|
| 00 | [Prepare a fresh Ubuntu 24.04 host](labs/00-prepare-ubuntu/README.md) | Docker Engine, kernel and Landlock requirements, host check | Platform requirements |
| 01 | [Install OpenShell and meet the gateway](labs/01-install-and-gateway/README.md) | Pinned install, gateway service, `doctor`, `gateway.toml` + preflight | Gateway, CLI, packaging |
| 02 | [Sandbox basics](labs/02-sandbox-basics/README.md) | create / exec / connect / stop / start / delete, `--no-keep`, restart policies | Sandbox lifecycle |
| 03 | [Bring your own image](labs/03-custom-images/README.md) | Custom images, the non-root rule, a policy baked into an image | Workload images, policy precedence |
| 04 | [Default-deny networking](labs/04-network-default-deny/README.md) | Deny-all egress, rules scoped to a **binary**, deny logs, SSRF guards | L4 network policy |
| 05 | [L7 REST rules](labs/05-l7-rest-rules/README.md) | Read-only presets, method and path allows, deny rules, audit vs enforce | L7 request inspection |
| 06 | [Filesystem and process controls](labs/06-filesystem-and-process/README.md) | Landlock paths, UID/GID, which sections lock at startup | Landlock, process identity |
| 07 | [Policy lifecycle](labs/07-policy-lifecycle/README.md) | Policy files, dry-run, `--wait`, revisions, rollback, global policy | Hot reload, revisions |
| 08 | [Providers: credentials the agent never sees](labs/08-providers-and-credentials/README.md) | Profiles, placeholders, endpoint binding, rotation | Credential injection |
| 09 | [Files, SSH, and editors](labs/09-files-and-ssh/README.md) | Upload with `.gitignore` filtering, confined download, SSH config, VS Code/Cursor | File transfer, SSH |
| 10 | [The policy advisor](labs/10-policy-advisor/README.md) | Drafts from denials, agent proposals over `policy.local`, auto-approval | Policy advisor |
| 11 | [The policy prover](labs/11-policy-prover/README.md) | SMT-based boundary proofs, counterexamples, a CI gate | Formal verification |
| 12 | [Ports, forwarding, services](labs/12-ports-and-services/README.md) | SSH and gRPC port forwards, gateway service URLs | Connectivity |
| 13 | [Templates, labels, settings](labs/13-templates-labels-settings/README.md) | Reusable workload templates, selectors, sandbox and global settings | Fleet management |
| 14 | [Observability](labs/14-observability/README.md) | OCSF shorthand logs, full OCSF JSON for a SIEM, gateway logs | Audit and logging |
| 15 | [The Python SDK](labs/15-python-sdk/README.md) | Create, exec, and delete sandboxes from Python | SDKs |
| 16 | [Protocol-aware rules](labs/16-protocol-rules/README.md) | GraphQL operations, **MCP tool calls**, WebSocket, raw TCP | L7 protocols |
| 17 | [Capstone: run a real AI agent](labs/17-run-an-agent/README.md) | OpenCode + OpenRouter (free model) under policy, granting access as it asks | Everything together |
| 18 | [Clean up, upgrade, uninstall](labs/18-cleanup/README.md) | Cleanup script, upgrades, uninstall, where to go next | Operations |

Time: about **6–7 hours** in total. Labs 00–08 are the core path (~3 hours). After Lab 08,
the labs are mostly independent: pick the ones you need.

**Not covered hands-on** (needs more than one VM): Kubernetes/Helm, the MicroVM and Podman
runtimes, OIDC authentication, credential refresh and token exchange, middleware and
interceptors. [Lab 18](labs/18-cleanup/README.md#4-going-further) maps them to the upstream
docs.

## Repository layout

```text
labs/NN-name/
  README.md        the lab: concepts, steps with real expected output, exercises
  test.bats        automatic checks for the lab (bats)
  solution.sh      self-playing walkthrough: types each command and runs it for real
  solution.log     \  the same walkthrough recorded with util-linux `script`
  solution.timing  /  → scriptreplay --timing solution.timing solution.log
  solution.cast       asciinema recording of the same run → asciinema play solution.cast
  *.yaml / *.json  policies, profiles, and proposals the lab uses
images/            workload images (tools image, image with a baked-in policy)
scripts/           host check, autoplay helper, recorder, cleanup
tests/helpers.bash shared test helpers
VERSION            the OpenShell version the course targets (0.1.4)
```

## Make targets

```shell
make check-host            # prerequisites
make images                # build the training images
make test                  # run every lab's checks (~8 min, creates and deletes real sandboxes)
make test LAB=08           # one lab
make solution LAB=08       # live replay (PAUSE=0 TYPE_SPEED=0 for full speed, INTERACTIVE=1 to step)
make replay LAB=08         # recorded replay with scriptreplay
make replay-cast LAB=08    # recorded replay with asciinema
make record LAB=08         # re-record a solution after changing it
make cleanup               # remove everything the course created
```

## Tools used

- **[bats-core](https://github.com/bats-core/bats-core)** (`sudo apt install bats`): the test
  runner for the lab checks.
- **`script` / `scriptreplay`** (util-linux, preinstalled): records and replays the solutions.
- **[asciinema](https://asciinema.org)** (`sudo apt install asciinema`, optional): plays the
  `.cast` recordings, which also embed on the web.

The checks use public echo services (`postman-echo.com`, `httpbin.org`, `tcpbin.com`,
`countries.trevorblades.com`, `mcp.deepwiki.com`, `ws.postman-echo.com`) as safe targets,
so you need outbound internet access. Lab 17's live agent test runs only when
`OPENROUTER_API_KEY` is set.

## References

- OpenShell source and docs at the course version:
  [github.com/NVIDIA/OpenShell/tree/v0.1.4](https://github.com/NVIDIA/OpenShell/tree/v0.1.4)
  ([docs/](https://github.com/NVIDIA/OpenShell/tree/v0.1.4/docs))
- Published documentation: [docs.nvidia.com/openshell](https://docs.nvidia.com/openshell/latest/index.html)
- Upstream examples: [examples/](https://github.com/NVIDIA/OpenShell/tree/v0.1.4/examples)

## License

Apache License 2.0, the same as OpenShell. See [LICENSE](LICENSE).
