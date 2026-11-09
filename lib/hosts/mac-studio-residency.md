# Mac Studio residency budget

The Studio keeps the Qwen and MiMo workers resident, with the API gate routed
only to Qwen. Their per-model worker width and request admission are set in
`lib/hosts/mac-studio.nix` and `hosts/mac-studio/home.nix`.

## Configured envelope

The host keeps `maxLocalLlmGb = 100`, which derives a `102400 MiB` wired-memory
ceiling on the 128 GB machine and leaves 28 GiB outside that ceiling. The
residency budget permits two workers and sets `memoryHardLimitGb = 32` for each.
The resulting sizing arithmetic is:

```text
2 workers × 32 GiB                       = 64 GiB
64 GiB workers + 4 GiB non-MLX baseline = 68 GiB
68 GiB + 24 GiB session allowance       = 92 GiB of 100 GiB wired budget
92 GiB + 28 GiB OS/headroom             = 120 GiB of 128 GiB physical memory
```

This leaves 8 GiB of nominal margin in each total. The model worker runs one
active sequence; the API gate and the local proxy admit at most two requests
per model, allowing one active request and one waiting request. Qwen's planned
131072-token stream uses about 8 GiB of KV; MiMo's planned 40960-token stream
uses about 1.25 GiB. The derived prompt-cache limit can shrink when the
per-worker budget is lowered.

`memoryHardLimitGb` is a sizing guideline, not a hard refusal. MLX may shed
buffer cache as it approaches the configured value and may still exceed it.
The arithmetic is therefore a configuration target, not proof that open agent
sessions stay safe under peak load. Measure memory pressure with sessions open
and a full-context request before enabling router traffic.

## Model estimate arithmetic

The read-only lane plan's component estimates do not add to its stated model
envelopes: `13.7 + 8 + 16` is 37.7 GiB for Qwen, and `6.7 + 1.25 + 2` is 9.95
GiB for MiMo. Recheck whether the RSS observations already include any cache or
KV allocation before treating those components as independent. This host
configuration uses the explicit 32 GiB per-worker sizing target and one active
sequence per model; it does not claim that the plan's prompt-cache targets are
fully resident.

The shared 100 GiB ceiling is unchanged because it also feeds the cluster wired
limit. This configuration does not change cluster mode, rank, RDMA, or cluster
memory guards.
