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
phase, so any daemon (re)start always sees current config.

## Managed-mode remnants

On the first standalone start, any fleet-enrollment state (`.enrolled`,
`local/_system/instance.yml`, `local/edge/instance.yml`) is moved into
`<dataDir>/retired-managed-state/` — retained, never deleted — so a prior
fleet identity remains recoverable.

## Packs

Packs still deploy declaratively via `programs.cribl-edge.packs`
(GitHub-released `.crbl` archives pinned by hash). Standalone config and packs
compose: instance config under `local/edge/`, packs under
`default/<pack-name>/`.

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
