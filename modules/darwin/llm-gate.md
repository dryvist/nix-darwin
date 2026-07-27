# llm-large L7 gate

Design notes for `llm-gate.nix` (launchd Caddy, secrets pulled live from
OpenBao). The module is the code; this file is the rationale that used to live
in its header comment.

## Role

[ADR](https://docs.dryvist.com/d/decisions/llm-large-studio-serving/): the model
server stays bound to 127.0.0.1; this Caddy front terminates TLS on the host's
LAN address and enforces a bearer token (the OpenAI `api_key` field, native in
every consumer). It is the only network path to the model port.

API-only: the chat UI moved to the single cluster-hosted Open WebUI, so this
gate no longer fronts a local web UI. `extraHostnames` lets the one API site
also answer for service aliases (e.g. an `llm-large.<subdomain>` CNAME) so the
cert/SNI covers them alongside the host FQDN.

## Loopback bind

Each gate site pins its listener to the host's LAN address via `bindAddresses`,
never the wildcard socket. `apiPort`/`clusterPort` mirror their loopback
upstream ports, so a wildcard listener would also own `127.0.0.1:PORT`; when
llama-swap drops its specific loopback bind, Caddy would capture loopback
traffic into its own TLS listener and clients would see "Client sent an HTTP
request to an HTTPS server". Binding the LAN address guarantees `127.0.0.1:PORT`
is answered by llama-swap or refused, never by the gate.

## Secrets

Secrets are NOT stored on this host. Nothing sensitive is baked into the
Caddyfile, the plist, or sops — not the bearer token, not the Route53 ACME
credentials, not even the AWS region (infra topology is treated as sensitive in
a public repo). OpenBao is the single source of truth. The launchd agent wraps
Caddy in `openbao-run`, which logs in with the least-privilege llm-gate AppRole
and injects the secrets as environment variables live at each (re)start; the
Caddyfile references them purely as `{env.VAR}` placeholders that Caddy resolves
at parse time. Rotate a value in OpenBao and restart the agent — nothing local
ever holds a copy. (This removes the external Doppler dependency that previously
fronted the gate; a lapsed Doppler token once took the whole serving path down,
which is exactly what OpenBao-native avoids.)

User agent, not root daemon: the gated port is non-privileged, and the gate's
OpenBao secret-zero (BAO_ADDR + the llm-gate AppRole role_id/secret_id) lives in
a user-owned 0600 env file (`secretZeroEnvFile`) that openbao-run sources at
each (re)start — the agent comes up unattended with no keychain and no ambient
session. Keychains are banned here: only the login keychain auto-unlocks, and a
custom keychain starts locked in every new security session, so the old keychain
design could never start unattended (2026-07 outage). The env file holds only a
pointer to OpenBao (the AppRole), never fetched secrets.

## TLS modes

- `route53` — real Let's Encrypt cert via DNS-01 against the public zone, using
  the least-privilege `acme` AWS user the cluster ingress also uses (credentials
  from OpenBao `secrets-external/platform/acme`).
- `internal` — Caddy's local CA (autonomous, no external dependency); clients
  must trust the CA or skip verification. Bring-up stopgap only.

## The L6 input bound (`maxRequestBytes`)

`request_body { max_size }` on both gated sites. A larger body gets 413 and is
never forwarded.

**Why the gate owns it.** It is the only hop that can refuse an oversized
prompt before anything allocates KV for it. `mlx_lm.server` has no
input-token flag at all; llama-swap has no body or token limit; the prompt
cache evicts only idle entries, and only after the request has already been
admitted. Caddy orders `request_body` ahead of `reverse_proxy`, so the refusal
is structural rather than a convention someone has to maintain. The gate is
also already the sole edge — llama-swap binds loopback and every LAN caller
passes through here for TLS and the bearer token — so there is no bypass.

`413` is deliberate: a status a caller can report and act on, never a hang and
never a silent truncation.

**Why bytes, and what that does not buy.** Caddy cannot tokenize. At roughly
3-4 bytes per token the default bounds a request well inside the KV budget the
serving math assumes, and it rejects the realistic runaway — a ballooning agent
transcript, a pasted repository. It is **not** a guarantee: a pathological
mostly-single-byte-token body could stay under the cap and still exceed the
intended token count. A sound token bound needs tokenization at the gate, which
nothing in the path does today; measure this cap in production before writing
that.

**Why the value is defined here.** Nothing upstream declares an input-token
cap to derive from. nix-ai's `maxRequestTokens` caps client-requested
`max_tokens` — *output*, despite the name — so it is not this value. The gate
being the only consumer, one definition at the consumer is the whole of it.

Serving arithmetic this feeds: the MLX memory-ceilings page in the companion
docs site (`d/hosts/ai/mlx-memory-ceilings`), which derives the KV cost per
token and the per-worker footprint this cap is sized against.
