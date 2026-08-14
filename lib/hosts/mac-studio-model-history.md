# mac-studio model selection history

Superseded measurement records for `lib/hosts/mac-studio.nix`, split out of
`mac-studio.md` when that file reached the 12 KiB file-size error limit
(`.file-size.yml` recommends splitting rather than extending the ceiling).

These verdicts are kept because they are evidence, not because they describe
the current deployment — for that, read `mac-studio.md` "Two warm brains".

## Resident model selection (2026-07-27)

Promoted from the Coder-30B to the 35B for standalone operation (MacBook
unplugged, no cluster).

Every candidate was measured on this host against a dedicated isolated worker on
a scratch port, with the loaded checkpoint confirmed by
`lsof -i :PORT` → pid → `ps -p <pid>` reading `--model`. **That step is
mandatory, not ceremony**: the server echoes the requested name back, so a
model id in a request or a response proves nothing about which weights
answered. It mattered doubly under the single-model mode this host ran until
2026-08-14, which aliased every other model's physical id onto the one
resident entry — but the response field was never evidence in either mode.

Headline metric is cumulative tok/s — `(prompt + completion) / wall` — so
prefill gains count. Identical 111–118 token prompt, 300 `max_tokens`, 3 timed
runs after a discarded warmup, decode-concurrency 1:

| model | cumulative | decode | ttft | tools |
| --- | --- | --- | --- | --- |
| Qwen3.6-35B-A3B-4bit | **115.2** | 84.9 | 0.12s | PASS |
| Qwen3-Next-80B-A3B-Instruct-4bit | 97.5 | 71.5 | 0.08s | PASS |
| GLM-4.7-Flash-4bit | 95.8 | — | — | FAIL |
| gpt-oss-120b-MXFP4-Q8 (peer-measured) | 51–54 | 40–43 | 0.23s | FAIL |

The 35B wins on throughput outright while being the smallest of the four
(19.4 GB). GLM-4.7-Flash is disqualified on tool calls, not speed: given two
tools it emits no call at all and stops on `length`. gpt-oss-120b is
disqualified because mlx-lm ships no harmony parser, so `tool_calls` is null and
raw `<|channel|>` markup leaks into content.

Thinking is off in its catalog entry, which matters for Hermes: a thinking
variant spends hundreds of reasoning tokens before it emits a tool call, and
Hermes pays that latency on every action it takes.
