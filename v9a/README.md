# v9a — IQ2_S expert FFN (champion)

**Status:** SERVING on .44. The best quality/size/speed point so far.

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

## Verdict
CHAMPION. IQ2_S experts recover ~10 HumanEval points vs v8 at modest size
cost. Next lever for the v3-parity gap is keeping experts at native MXFP4
(Q4-equivalent, ~0% weight error) — see Unsloth QAT analysis in root README.
