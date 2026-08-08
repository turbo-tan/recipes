# DeepSeek-V4-Flash-0731 TQ3_4S quantization recipes

Reproducible tensor-type recipes for quantizing DeepSeek-V4-Flash-0731 (284B/13B active)
with the `turbo-tan/llama.cpp-tq3` fork (adds TQ3_4S / TQ3_0 / TQ3_1S TurboQuant types).

Each folder = one recipe. Contents:
- `tensor_types.txt` — the `--tensor-type-file` input (regex=type per tensor)
- `README.md` — exact quantize command + measured benchmarks

## Common command shape

```bash
llama-quantize \
  --allow-requantize \                      # required: source has native MXFP4 experts
  --imatrix dsv4_v4.imatrix \               # importance matrix for expert tensors
  --tensor-type-file <recipe>/tensor_types.txt \
  --output-tensor-type q6_K \
  --token-embedding-type q6_K \
  --include-weights ffn_gate_exps --include-weights ffn_up_exps --include-weights ffn_down_exps \
  DeepSeek-V4-Flash-0731-UD-Q8_K_XL-00001-of-00005.gguf \
  out.gguf TQ3_4S 32
```

Source: `unsloth/DeepSeek-V4-Flash-0731-GGUF` UD-Q8_K_XL (bit-exact QAT repack).
NOTE: flags must come BEFORE positional args (this binary parses flags-first).

Imatrix: `dsv4_v4.imatrix` (~449 MB, not in this repo — regenerate with
`llama-imatrix` on the UD-Q8_K_XL source with a code-heavy calibration set).
Archived at `ai_workspace/dsv4_v4.imatrix` on the build box.

## Recipes

| recipe | expert gate/up | expert down | shexp/attn | size (MiB) | status |
|---|---|---|---|---|---|
| v8  | IQ2_XXS | q3_K/q4_K | q6_K | 91,062 | deleted (superseded by v9a) |
| v9a | IQ2_S   | q2_K/q3_K | q6_K | 92,487 | **champion** |
| v9b | IQ2_S   | q2_K/q3_K | q4_K | 91,511 | built, eval pending |
| v9c | IQ2_XXS | q2_K/tq3_0 | q6_K | ~88,871 dry-run | **abandoned** (Unsloth QAT analysis: IQ2_XXS experts = >30% weight error) |

## Serving (DGX Spark GB10)

```bash
llama-server -m <gguf> -ngl 99 -c 524288 -np 4 --port 8085 \
  -ctk q4_0 -ctv tq3_0 --alias <name> --reasoning-format deepseek \
  --reasoning-budget 256
```

DSpark speculative decoding (~1.9x decode with `--spec-draft-n-max 3`):
requires the official dspark drafter (`dspark-DeepSeek-V4-Flash-0731-Q8_0.gguf`,
11G, do NOT requantize — it grows). Fork patch needed first:
`dflash.attention.sliding_window_pattern` must be optional (official drafter
omits it; upstream requires it). +10G RAM headroom needed.
