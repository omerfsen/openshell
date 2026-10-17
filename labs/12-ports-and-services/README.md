# Lab 12 — Ports, forwarding, and exposed services

**Goal:** reach a server running *inside* a sandbox from your machine: with a local port
forward, a gRPC service forward, and a gateway-managed URL.
**Time:** ~15 minutes. **Prerequisite:** [Lab 11](../11-policy-prover/README.md).

## Concepts

Agents often start things you want to look at: a dev server, a notebook, a dashboard. The
workload has no network device, so nothing inside is reachable directly. Instead, a server
**binds to loopback inside the sandbox** and OpenShell carries traffic to it:

| Method | Command | Transport | Best for |
|---|---|---|---|
| SSH port forward | `openshell forward start <port> <sandbox>` | SSH tunnel via gateway | Local development, any TCP |
| gRPC service forward | `openshell forward service <sandbox> --target-port N --local M` | Gateway gRPC (no SSH) | Hosts without a usable SSH client |
| Exposed service | `openshell service expose <sandbox> <port> [name]` | Gateway HTTP router | A stable URL like `http://default--web.openshell.localhost:17670/` |

Inbound traffic doesn't need a network rule. Network policy governs only connections the
sandbox **opens**.

## 1. Start a server in a sandbox

Make the server the sandbox's main process:

```shell
openshell sandbox create --name web --from openshell-training/tools:0.1.4 --no-auto-providers --detach \
  -- python3 -m http.server 8000 --bind 127.0.0.1 --directory /tmp
openshell sandbox exec -n web -- sh -c 'echo "<h1>hello from a sandbox</h1>" > /tmp/index.html'
openshell sandbox exec -n web -- curl -s http://127.0.0.1:8000/
```

## 2. Forward a local port (SSH)

```shell
openshell forward start 8000 web -d          # background
openshell forward list
curl -s http://127.0.0.1:8000/
openshell forward stop 8000 web
```

`--forward 8000` on `sandbox create` does the same at creation time.

## 3. Forward over gRPC (no SSH needed)

```shell
openshell forward service web --target-port 8000 --local 18000 &
sleep 3
curl -s http://127.0.0.1:18000/
kill %1
```

```text
✓ Forwarding 127.0.0.1:18000 -> 127.0.0.1:8000 in sandbox web via gRPC
```

## 4. Expose a service URL

```shell
openshell service expose web 8000
```

```text
✓ Exposed sandbox web -> 127.0.0.1:8000
  URL: http://default--web.openshell.localhost:17670/
```

```shell
curl -s http://default--web.openshell.localhost:17670/
openshell service list
openshell service get web
```

The URL is `<workspace>--<sandbox>[--<service>].openshell.localhost` on the gateway port.
`*.localhost` resolves to loopback on Linux, so no DNS setup is needed. A named service
gets its own URL: `openshell service expose web 8000 docs`.

By default the gateway **strips** any incoming `Authorization` header (`AUTHORIZATION: strip`
in `service list`), so a browser's credentials never reach the sandboxed app. Use
`--authorization-mode bearer-passthrough` when the app does its own bearer-token auth.

`--expose 8000` on `sandbox create` exposes the service as soon as the sandbox is ready.

```shell
openshell service delete web
openshell sandbox delete web
```

## Exercises

1. Run `python3 -m http.server 8000 --bind 0.0.0.0` instead. Does anything change for a client
   outside the sandbox? (The workload still has no network device.)
2. Expose two named services on one sandbox and list them.

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=12          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=12     # asciinema
labs/12-ports-and-services/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/12-ports-and-services/test.bats
```

**Next:** [Lab 13 — Templates, labels, and settings](../13-templates-labels-settings/README.md)
