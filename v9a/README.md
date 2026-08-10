# v9a — IQ2_S expert FFN (champion)

**Status:** SERVING on .44 (Spark) and validated at full 1M context on a single RTX 3090.
The best quality/size/speed point so far.

## Recipe intent
Fix v8's weak spot: raise expert `ffn_gate_exps` / `ffn_up_exps` from
IQ2_XXS → **IQ2_S**, paid for by dropping `ffn_down_exps` q3_K→q2_K and
q4_K→q3_K. Experts carry the routed MoE compute, so precision there buys
coding quality back. +1.4 GiB over v8, still below v3 (~103G).

## Quantize command (exact)

```bash
llama-quantize \
  --allow-requantize \
  --imatrix dsv4_v4.imatrix \
  --tensor-type-file v9a/tensor_types.txt \
  --output-tensor-type q6_K --token-embedding-type q6_K \
  --include-weights ffn_gate_exps --include-weights ffn_up_exps --include-weights ffn_down_exps \
  DeepSeek-V4-Flash-0731-UD-Q8_K_XL-00001-of-00005.gguf \
  DeepSeek-V4-Flash-0731-TQ3_4S_v9a.gguf TQ3_4S 32
```

Result: **92,487 MiB** (2.73 BPW), 1328 tensors, GGUF v3. Output 90.3 GiB.

## Benchmarks

Serving config (DGX Spark GB10, .44): 512K ctx, -ctk q4_0 -ctv tq3_0,
reasoning-ON budget 256, temp 0, parallel 4.

| benchmark | v9a | v8 | v3 (UD ref, tomfix) |
|---|---|---|---|
| HumanEval pass@1   | **0.909** | 0.811 | 0.945 |
| HumanEval+ pass@1  | **0.866** | 0.768 | 0.909 |
| MBPP pass@1        | **0.926** | 0.868 | 0.918 |
| MBPP+ pass@1       | **0.759** | 0.717 | 0.772 |
| Hard86 (36K, raw)  | **76/86** | 69/86 | — |
| MBPP wall time     | 6443s | 7070s | — |
| Benchloop overall (TOM prompt) | 76.0 (coding 100, toolcall 90) | — | — |
| gen tok/s (benchloop) | 18.9 | — | — |

v9a beats v8 on all four evalplus metrics (+5.8 to +9.8 pts), +7 Hard86,
~9% faster MBPP, at +1.4 GiB.

**v9a vs v3 same-harness benchloop (identical config):**
v9a wins coding (100 vs 93.8) and toolcall (90 vs 85); v3 wins dataextract
(91.6 vs 81.2) and instructfollow (75.6 vs 71.1); overall v3 +1.1.
Profile: v9a = coding/agentic specialist; v3 = extraction/instruction generalist.
For coding/agent serving, v9a is the correct choice.

Artifacts: `.44:~/code/ai_workspace/artifacts/evalplus/v9a_512k_ctkq4_q38/`,
Hard86 `.44:~/code/ai_workspace/artifacts/hard86/v9a_512k_ctkq4_q38/`,
Benchloop `.44:~/.bench-loop/runs/20260808-093115-v9a-local-openai_compat/run.json`

## Running recipe — local RTX 3090 @ 1M context (validated 2026-08-10)

Single consumer 3090 (24 GB) + 125 GB DDR4 serves the full quant at
**1,048,576 context, 14.2 tok/s**, arithmetic gate clean. Experts run on
CPU (DDR4-bound: perf shows ~63% of decode in iq2_S/q2_K dot products),
attention/dense on GPU.

```bash
# mlock requires root or ulimit -l unlimited — full 91 GB must be pinned,
# otherwise only 16 GB pins (default limit) and perf silently degrades
sudo -n bash -c 'ulimit -l unlimited; exec ./llama-server \
  -m DeepSeek-V4-Flash-0731-TQ3_4S_v9a.gguf \
  --host 127.0.0.1 --port 8086 \
  -c 1048576 -np 1 \
  -ngl 44 --n-cpu-moe 39 --load-mode mmap+mlock \
  -fa on -ctk q4_0 -ctv tq3_0 \
  --reasoning on --reasoning-budget 256 --reasoning-format deepseek --jinja \
  -t 16 -tb 16 -b 8192 --fit on'
```

Key flags and why:
- `-c 1048576 -np 1` — full 1M in one slot. np=1 is deliberate: with a
  single slot, parallel clients serialize instead of piling into the queue;
  a parallel-4 client against np=1 caused abandoned-request queue pileup
  and a `ggml_cuda_error` in `set_tensor` (VRAM pressure). np=1 + serial
  or parallel-2 client is the crash-proof combination.
- `-ngl 44 --n-cpu-moe 39` — attention + dense layers on GPU, all MoE
  experts on CPU. Naive partial offload (`-ngl 10`) is PCIe-bound: 1.9 t/s.
- `--load-mode mmap+mlock` + `ulimit -l unlimited` — pin the whole model.
  Without raising the limit mlock silently stops at 16 GB.
- `-ctk q4_0 -ctv tq3_0` — compressed KV makes 1M nearly free: 128K/512K/1M
  all within ±3% speed (14.3 / 13.9 / 14.0 t/s).
- `--fit on` — guards against CUDA OOM by auto-sizing unset args to VRAM
  (kept alongside explicit -c for the belt-and-braces).
- Reasoning budget 256 for benchmarks; **81,920 for garden-style creative
  tasks** (matches the Spark pi garden run).

Measured under this exact config (thinking ON, temp 0, TOM, official scorer):

| benchmark | local 3090 @1M | v9a Spark @512K |
|---|---|---|
| Hard86 | **77/86 (89.5%)** | 76/86 |
| HumanEval / HE+ | **93.3 / 89.0** | 90.9 / 86.6 |
| MBPP / MBPP+ | **92.6 / 77.5** | 92.6 / 75.9 |
| Benchloop overall | 77.8 (quality 85.3) | 76.0 |
| Decode tok/s | 14.2 | 18.9 |

Quality holds across substrates: the 3090@1M beats the Spark v9a on every
evalplus metric. Known quirks: DSpark Q8 drafter on CPU = −24% (don't use);
ngram-spec = neutral; KV tq3_0/tq3_0 = segfault (keep ctk q4_0).
Garden prompt at budget 81920 produced a unified centered pagoda
(`results/local-1m-3090/garden_local_1m_20260810.html`).

Speed ceiling on this box is DDR4 bandwidth; 25 t/s needs DDR5-class CPU or
a second GPU for experts.

Artifacts: `results/local-1m-3090/` (hard86, evalplus, benchloop.log,
garden_local_1m_20260810.html, decode_speed.json).

## Verdict
CHAMPION. IQ2_S experts recover ~10 HumanEval points vs v8 at modest size
cost. Next lever for the v3-parity gap is keeping experts at native MXFP4
(Q4-equivalent, ~0% weight error) — see Unsloth QAT analysis in root README.
