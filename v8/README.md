# v8 — IQ2_XXS expert FFN (superseded, deleted)

**Status:** DELETED 2026-08-08 (user-approved; model binary removed from .44,
eval scores preserved in benchmarks below). Recipe kept for provenance.

## Recipe intent
Size/speed play: expert gate/up at IQ2_XXS (2.06 bpw), offset with q3_K/q4_K
ffn_down. This was the fork's original "smaller than v3" design.

## Quantize command (exact)

```bash
llama-quantize \
  --allow-requantize \
  --imatrix dsv4_v4.imatrix \
  --tensor-type-file v8/tensor_types.txt \
  --output-tensor-type q6_K --token-embedding-type q6_K \
  --include-weights ffn_gate_exps --include-weights ffn_up_exps --include-weights ffn_down_exps \
  DeepSeek-V4-Flash-0731-UD-Q8_K_XL-00001-of-00005.gguf \
  DeepSeek-V4-Flash-0731-TQ3_4S_v8.gguf TQ3_4S 32
```

Result: **91,062 MiB** (dry-run verified; final quant matched).

## Benchmarks

Serving config (DGX Spark GB10, .44): 512K ctx, -ctk q4_0 -ctv tq3_0,
reasoning-ON budget 256, temp 0, parallel 4.

| benchmark | v8 | v9a (successor) | Δ |
|---|---|---|---|
| HumanEval pass@1   | 0.811 | 0.909 | **−9.8** |
| HumanEval+ pass@1  | 0.768 | 0.866 | **−9.8** |
| MBPP pass@1        | 0.868 | 0.926 | **−5.8** |
| MBPP+ pass@1       | 0.717 | 0.759 | **−4.2** |
| Hard86 (36K, raw)  | 69/86 | 76/86 | **−7** |
| MBPP wall time     | 7070s | 6443s | +9% slower |

Artifacts: `.44:~/code/ai_workspace/artifacts/evalplus/v8_512k_ctkq4_q38/`

## Verdict
IQ2_XXS experts cost ~10 HumanEval points. Unsloth's QAT analysis confirms
why: re-quantizing the native MXFP4 experts to IQ2_XXS produces >30% weight
error per layer. Do not use this recipe. v9a (IQ2_S experts) is the fix.
