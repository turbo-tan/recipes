# v9b — IQ2_S experts, shexp/attn down to q4_K (size-optimized sibling of v9a)

**Status:** BUILT (quant complete, GGUF verified). Eval battery pending.

## Recipe intent
Same expert recipe as v9a (IQ2_S gate/up, q2_K/q3_K down) — the quality tier
— but drops non-expert `ffn_*_shexp` and `attn_output_*` from q6_K to q4_K
to claw back ~1 GiB. Shared experts are always-on (small fraction of params),
so this is a minor quality risk for a size win.

## Quantize command (exact)

```bash
llama-quantize \
  --allow-requantize \
  --imatrix dsv4_v4.imatrix \
  --tensor-type-file v9b/tensor_types.txt \
  --output-tensor-type q6_K --token-embedding-type q6_K \
  --include-weights ffn_gate_exps --include-weights ffn_up_exps --include-weights ffn_down_exps \
  DeepSeek-V4-Flash-0731-UD-Q8_K_XL-00001-of-00005.gguf \
  DeepSeek-V4-Flash-0731-TQ3_4S_v9b.gguf TQ3_4S 32
```

Result: **91,511 MiB** (2.70 BPW), 1328 tensors, GGUF v3 — exactly the dry-run
prediction. Output 90 GiB.

## Benchmarks

Pending. Run the same battery as v9a for apples-to-apples:
evalplus (HE/HE+/MBPP/MBPP+), Hard86 (36K raw), Benchloop.
Serving config must match v9a exactly (512K ctx, ctk q4_0/ctv tq3_0,
reasoning-ON budget 256, temp 0, parallel 4).

Expected: near-v9a quality (experts identical), ~1 GiB smaller. If evalplus
drops meaningfully vs v9a, the q4_K shexp/attn cut is not worth it.
