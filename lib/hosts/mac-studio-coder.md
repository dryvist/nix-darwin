# The coding sidecar (Mac Studio)

Why `qwen3-coder-30b` is enabled here, why it holds `coding` and nothing else,
and why it is swap rather than resident. Its own file because
[mac-studio.md](./mac-studio.md) is already at its size budget, the same reason
[mac-studio-residency.md](./mac-studio-residency.md) is separate.

Enabled 2026-09-05 as the one deliberate re-enable the catalog comment asks
for.

## Why the role moved off the dense resident

`coding` sat on the model least suited to it. Measured on this hardware:

| | decode tok/s | time to first token, agentic prompt |
| --- | --- | --- |
| dense resident | 12–18 | 160–275 s |
| coder | 136.7 (concurrency 4) | 61–78 s |

Every request that asked for `coding` was being answered by the slowest model
on the host.

## Why it does not get `tool-calling`

Measured, not cautious. On the agentic grid the coder produces malformed tool
calls under concurrency and its multi-turn track collapses in the first round,
where the resident MoE runs a clean twenty. Single-stream its calls are well
formed and it is the fastest coder measured here.

So it answers code edits one at a time and never fronts a session's tools.
Giving it a tool-facing role would trade a clean brain for a fast one that
cannot hold a conversation.

## Why swap and not resident

17 GB of weights would be a third warm model against a residency budget sized
for two (see [mac-studio.md](./mac-studio.md), "Residency budget"), and coding
requests are bursty rather than continuous. It idle-unloads like every other
swap entry and pays a cold load on the next request.

## What to check after a rebuild

CI cannot see any of this.

- The entry appears in `~/.config/mlx/llama-swap.json`.
- A `coding` request loads it and answers.
- Both residents are still warm afterwards. A swap load must sit **beside**
  them, not evict one — that is what `maxResidentWorkers = 2` buys.

Once it answers here, the router registry entry for this model can flip to
`enabled: true`; it is marked NOT SERVED today.
