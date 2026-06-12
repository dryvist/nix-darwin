# Cribl Edge GitOps (standalone mode)

How this repo manages the macOS Cribl Edge node's configuration as code, and
why the node is standalone rather than fleet-managed.

## Policy

- **Cribl Cloud fleets are reserved for Linux machines** (VMs, containers,
  servers). macOS hosts run Cribl Edge in **standalone** mode with
  configuration owned by this repo (`programs.cribl-edge.mode = "standalone"`).
- Configuration is declarative: `programs.cribl-edge.standalone.configFiles`
  renders files from the Nix store into `<dataDir>/local/cribl/` on every
  `darwin-rebuild switch`.

## Why standalone + files (the Cribl-supported shape)

Cribl's documented configuration surface is a file tree under
`$CRIBL_HOME/local/cribl/` — `inputs.yml`, `outputs.yml`,
`pipelines/<name>/conf.yml`, `pipelines/route.yml` — and Cribl explicitly
supports bootstrapping nodes from these files
([Config Files](https://docs.cribl.io/edge/configuration-files/),
[inputs.yml](https://docs.cribl.io/edge/inputsyml/)). Cribl's GitOps feature
([GitOps](https://docs.cribl.io/stream/gitops/)) is Leader-centric — it
version-controls a distributed deployment's Leader config — which does not
apply to a single standalone Edge node. For a single node, version-controlled
config files deployed by a config-management system (this repo) are the
supported equivalent. With `CRIBL_VOLUME_DIR` set, the mutable copy of that
tree lives under the data volume (`/opt/cribl-data/local/cribl/`).

Cribl reloads local configuration changes without a daemon restart, so
activation only needs to install the files.

## Managed-mode remnants

On the first standalone start, any fleet-enrollment state (`.enrolled`,
`local/_system/instance.yml`, `local/edge/instance.yml`) is moved into
`<dataDir>/retired-managed-state/` — retained, never deleted — so a prior
fleet identity remains recoverable.

## Packs

Packs still deploy declaratively via `programs.cribl-edge.packs`
(GitHub-released `.crbl` archives pinned by hash). Standalone config and packs
compose: instance config under `local/cribl/`, packs under
`default/<pack-name>/`.

## Where the data goes

Inline sources on this host ship over Cribl TCP (S2S) to the HAProxy-fronted
Cribl Stream workers (port: `service_ports.cribl_s2s` in terraform-proxmox
constants), which forward to Splunk. Index/sourcetype are stamped at the Edge.
