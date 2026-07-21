# Cribl Edge GitOps (standalone mode)

How this repo manages the macOS Cribl Edge node's configuration as code, and
why the node is standalone rather than fleet-managed.

## Policy

- **Cribl Cloud fleets are reserved for Linux machines** (VMs, containers,
  servers). macOS hosts run Cribl Edge in **standalone** mode with
  configuration owned by this repo (`programs.cribl-edge.mode = "standalone"`).
- Configuration is declarative: `programs.cribl-edge.standalone.configFiles`
  renders files from the Nix store into `<dataDir>/local/edge/` on every
  `darwin-rebuild switch`.

## The `edge` config tree (load-bearing)

Cribl Edge reads its I/O configuration — `inputs.yml`, `outputs.yml`,
`pipelines/<name>/conf.yml` — from the **`edge` config tree**: it merges
`local/edge/` over the package's `default/edge/`. The `cribl` tree
(`local/cribl/`) is Cribl **Stream's** config location; on an Edge node it
holds only runtime system files (`auth/`, `cribl.inited`), and any I/O config
placed there is silently ignored.

This module originally installed its files into `local/cribl/`, and the
failure mode was invisible: the node ran healthily on the `default/edge/`
sources (system metrics/state) while the declared file inputs and the Splunk-
bound output simply did not exist — zero events shipped, zero errors logged.
When debugging "no events arrive," first confirm the running inputs (worker
log `input:<id>` channels) match the declared ones.

## Why standalone + files (the Cribl-supported shape)

Cribl's documented configuration surface is a file tree —
([Config Files](https://docs.cribl.io/edge/configuration-files/),
[inputs.yml](https://docs.cribl.io/edge/inputsyml/)) — and Cribl explicitly
supports bootstrapping nodes from these files. Cribl's GitOps feature
([GitOps](https://docs.cribl.io/stream/gitops/)) is Leader-centric — it
version-controls a distributed deployment's Leader config — which does not
apply to a single standalone Edge node. For a single node, version-controlled
config files deployed by a config-management system (this repo) are the
supported equivalent. With `CRIBL_VOLUME_DIR` set, the mutable copy of the
tree lives under the data volume (`/opt/cribl-data/local/edge/`).

Cribl reads these files only at startup — it does NOT hot-reload config
written outside its own API (verified empirically). The module therefore
installs them in `extraActivation`, which runs before nix-darwin's launchd
phase, so any daemon (re)start sees current config on disk.

## Applying config changes (the restart gate)

Installing the files is not enough to get them into the running daemon. Two
things defeat `extraActivation` on its own:

1. nix-darwin's launchd phase does **not** reliably restart Edge when only the
   plist env changes (observed: the daemon PIDs were unchanged across a
   `darwin-rebuild switch`).
2. A running standalone Edge periodically **autosaves its in-memory config back
   over `local/edge/`** (and `default/edge/`), clobbering the freshly-installed
   files before any restart — so the next restart would reload stale config.

So `cribl-edge.nix` adds a marker-gated `postActivation` script,
`scripts/cribl-edge-restart-on-change.sh`. It runs **after** the launchd phase
(current-generation plist loaded), and `launchctl kickstart -k`s the daemon
exactly when the declared config has changed — closing the autosave-clobber
window seconds after install. The gate compares a `sha256` of the declared
config against the marker file `<dataDir>/.declared-config-sha`; on a match it
does nothing, so unrelated switches don't gratuitously restart the daemon.

The hash covers **both** `standalone.configFiles` **and** `packs` (the pinned
derivation paths), so a pack-only version bump still triggers a restart — an
earlier plist-only sha hashed just the config files and missed pack changes.
The brief restart gap is covered by the Edge persistent queue and
`services.launchdSelfHeal` (see `docs/LAUNCHD-SELF-HEAL.md`).

## Managed-mode remnants

On the first standalone start, any fleet-enrollment state (`.enrolled`,
`local/_system/instance.yml`, `local/edge/instance.yml`) is moved into
`<dataDir>/retired-managed-state/` — retained, never deleted — so a prior
fleet identity remains recoverable.

## Packs

Packs deploy declaratively via `programs.cribl-edge.packs` (GitHub-released
`.crbl` archives pinned by hash). Standalone config and packs compose: instance
config under `local/edge/`, packs under `default/<pack-name>/`.

But on a standalone Edge a pack does **not** run end-to-end on its own (verified
live via the local API):

- The pack's own `default/inputs.yml` Sources are **never instantiated** — the
  worker only initializes worker-level inputs.
- The pack's **internal routing layer never loads** — the API serves every pack
  a fallback `filter:true → pipeline:main` route (a `main` pipeline none of
  these packs define), so events QuickConnected into `pack:<id>` pass through
  **unprocessed** (seen in Splunk as port-stamped sourcetype with no `llm.*`
  fields).

So the deployed pattern (see `hosts/common/cribl.nix`) declares the **feeder
file inputs at the worker level** and QuickConnects them straight into the pack
**pipelines**, which are installed as worker-level `pipelines/<name>/conf.yml`
read **verbatim** from the fetched pack derivations (`builtins.readFile
"${pack}/default/pipelines/.../conf.yml"`). The released `.crbl` stays the
single source — nothing is copy-pasted — while the pack still deploys under
`packs` for provenance/UI. This is the same worker-level-pipeline + QuickConnect
path already proven by `llm_logs`/`firewall_logs`.

Two file-input details that bite here:

- **`filenames` globs match the full path, not the basename**, so every pattern
  must lead with `*/` (e.g. `"*/rollout-*.jsonl"`). A leading-wildcard-less
  pattern silently matches nothing — health Green, zero files tracked (#1623).
- **The AI-CLI transcript inputs attach a dedicated `AI CLI JSONL` event
  breaker with a 4 MiB `maxEventBytes`** (`breakers.yml`): single JSONL lines
  routinely exceed Cribl's stock 51200-byte limit (codex rollout lines >1 MiB
  observed), which would otherwise split one JSON line into unparseable
  fragments.

## Where the data goes

Inline sources on this host ship over TCP JSON to the HAProxy-fronted Cribl
Stream workers, which forward to Splunk. Index/sourcetype are stamped at the
Edge. TCP JSON, not Cribl TCP: the `cribl_tcp` destination is refused on a
standalone node ("Destination is not allowed in this deployment" — it
requires a distributed deployment) and TCP JSON is Cribl's documented
single-instance substitute. The receiving side (contracts port
`cribl_tcpjson`, HAProxy frontend, Stream `tcpjson` source) is tracked in
ansible-proxmox-apps#525; until it lands, the Edge persistent queue buffers
events locally and flushes when the port comes up.
