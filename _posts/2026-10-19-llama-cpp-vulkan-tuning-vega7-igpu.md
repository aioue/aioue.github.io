---
layout: post
title: "llama.cpp on a Vega 7 iGPU: the GPU won, the tuning knobs did not"
date: '2026-10-19T05:20:00+01:00'
last_modified_at: '2026-10-19'
tags: [llama.cpp, vulkan, amd, igpu, homelab, benchmark]
hidden: false
---

Two days of benchmarking Qwen3 on an integrated Radeon Vega 7, first on CPU and then on the iGPU through Vulkan, with a llama-bench tuning sweep in between. The headline: full GPU offload doubled real-world decode and cut time-to-answer by a third. Every tuning knob that looked promising in synthetic benchmarks lost or drew in real serving, so production kept its plain settings.

## The box

| Component | Detail |
|-----------|--------|
| APU | AMD Ryzen 5 PRO 5650G (6C/12T Zen 3) |
| iGPU | Radeon Vega 7, gfx90c, full offload via Vulkan (`RADV`, Mesa 26.0.8) |
| RAM | 32 GB DDR4 at stock 3200 MT/s, shared with the iGPU |
| Guest | LXC container, Ubuntu 26.04, 12 GB RAM, `llama-server` behind an authenticated Caddy |
| llama.cpp | pinned `620d2225` (v0.7.0-dev), one build for bench and serve |

Serving configuration: `ctx 8192`, `threads 12`, `ubatch 512`, f16 KV cache, flash attention at the build default, `n-gpu-layers` full. Benchmarks ran with the machine otherwise idle, GPU legs with the server stopped and CPU legs with it stopped too, each number from its own server process.

## GPU against CPU

Qwen3 4B (Q4_K_M), measured two ways. The HTTP numbers are the honest ones: a prompt and a 128-token generation through `llama-server`, median over a full run.

| Path | Decode t/s | HTTP median |
|------|-----------:|------------:|
| CPU only, 12 threads | 3.52 | 25.9 / 26.4 s |
| Vulkan, all layers | 6.99 | 16.98 s |

Twice the tokens, a third less waiting. The `llama-bench` decode number and the served number agree closely (6.6 to 7.0 t/s), which is worth knowing: on this box the server adds little to per-token cost.

The 900-second soak passed 38/38 on the GPU path, and a 12-question quality battery looked no worse than CPU output.

## The 9B result is the interesting one

Qwen3 9B (IQ3_M), a model 2.7 times larger: **7.48 t/s decode, 85.5 t/s prefill** in a clean `llama-bench`, a 900-second soak at `ctx 8192` passing 29/29 with a 23.6 s median, and 12/12 on the quality battery.

The 9B decodes at the same speed as the 4B. On a shared-memory iGPU, decode is bound by a fixed per-token cost of about 133 ms that has nothing to do with model size in this range. Prefill still scales with compute (85 t/s for the 9B, 160 for the 4B), so long prompts got slower; token generation did not.

## The knobs

`llama-bench` sweep against the 4B, `-p 512 -n 128`, all Vulkan, all layers offloaded, server stopped. Baseline is the production configuration.

| Change | Decode t/s | vs baseline |
|--------|-----------:|------------:|
| baseline (`ub 512`, f16 KV, stock env) | 6.58 | - |
| disable GTT spill + host-visible vidmem off (combo) | 7.08 | +7.7% |
| larger Vulkan heap (scoped `drirc`) | 6.90 | +4.9% |
| `--no-mmap`, limit 50 | 6.88 | +4.6% |
| `ubatch 2048` | 6.87 | +1.5% |
| flash attention on | 6.66 | +1.3% |
| `ctx 4096` | 6.74 | flat |
| GTT spill disable alone | 6.73 | +2.2% |
| `--no-mmap`, limit 20 | 6.74 | flat |
| `ctx 8192` | 6.51 | flat |
| prefer host memory | 6.47 | -1.7% |
| KV cache q8_0 at depth 8064 | 6.41 | -2.6% |

KV depth made no difference at all: depth 4096 and depth 8064 landed within noise of each other, and context length moved nothing.

## How to read it

| Question | Answer |
|---|---|
| Which path for serving? | Vulkan, all layers. It wins decode outright and needs no patching |
| Did any knob earn production adoption? | No |
| Why not the +7.7% combo? | See below: it lost in real serving |
| Is the 9B viable? | Yes, same decode speed as the 4B, slower prefill |

## Synthetic wins, real losses

The +7.7% combo was the one knob worth chasing, so it got an HTTP trial through the real server: **17.28 s median against 16.98 s for plain settings**. The synthetic gain inverted at the serving layer, so the environment overrides came back off the box and production stayed where it was.

This is the result I would want to find before adopting anything: a tuning leg that only runs `llama-bench` would have shipped a regression. The 4.6% and 4.9% rows probably hold the same cargo, and I did not spend HTTP trials on them because the best candidate already failed.

## The thread-count trap, discarded

The sweep originally contained rows for running the GPU path at 2, 4, 6 and 8 threads. Those numbers showed decode jumping dramatically at every thread count except 12. Verification runs proved the pattern was an artifact of `llama-bench` timing on Vulkan at non-default thread counts, not real throughput: interleaved controls at 12 threads sat at the production value while the same run reported inflated figures for the others. Those rows are discarded rather than published. If you benchmark Vulkan on an APU, keep `-t` at your physical core count and be suspicious of anything that wins by changing it.

## Why other people quote higher numbers

Community posts for these APUs regularly claim 10 to 12 t/s on models this size. Nothing in this sweep contradicts them:

- Most quoted numbers are raw `llama-bench`, often `-p 0` with short generation and cache reuse. This post separates bench from serving for exactly that reason.
- The per-token overhead floor dominates here. A setup with less of it shows a higher number on identical silicon.
- Speculative decoding from the model's own MTP head is the legitimate way to break the floor, and the pinned build here loads MTP weights but never uses them. [daimonionnn's amd-vega-rocm-vulkan-llm-toolkit](https://github.com/daimonionnn/amd-vega-rocm-vulkan-llm-toolkit) measured +38% decode on an MoE model and -5% on a dense 9B with it, which fits the overhead picture: a bandwidth-saturated dense model has no headroom left to buy tokens with.
- Lighter serving settings (shorter context, cheaper cache, faster RAM) all help an iGPU. This box runs `ctx 8192` for reliability and stock 3200 MT/s memory, and decode scales with DDR4 bandwidth on shared-memory graphics.

## When the host wedges

One operational note from the middle of the sweep: two overlapping benchmark sessions starved the Proxmox host badly enough to cost it an SSH login, and it took a console reset. The guard that watches the host had tripped on a PVE probe timeout and stayed latched after recovery. It now disarms when the operator clears the marker, and benchmark legs hold a lock file plus a remote lease so a second session cannot start while one is running. Bench your own box serially; shared-memory iGPUs do not degrade gracefully under contention.

## Raw data

All numbers above come from JSON results captured per run, plus a written report for the tuning leg, in the homelab repo. The 4B GPU profile and both soak logs were accepted by the tooling only at `ctx 8192`; the 9B's first soak at 4096 was rejected by the acceptance rule and re-run at depth, which is why the two soaks cite the same context.
