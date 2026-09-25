# Qwen3.8 27B TQ3_4S MTP decode recipe for RTX 3090

This recipe selects the fastest validated sampler topology for Qwen3.8 27B
`TQ3_4S` self-speculative decoding on an RTX 3090:

- target-model sampling on the CPU
- MTP draft sampling on the GPU
- TQ3_0 K and V cache
- fused MTP chain with two draft tokens
- 32,768-token server context

Target backend sampling is intentionally disabled. On the tested build, its
interaction with multi-output speculative verification reduced MTP acceptance,
made fixed-seed requests variable, and lowered mean decode speed.

## Requirements

- NVIDIA RTX 3090 24 GB
- CUDA 13.0 build targeting `sm_86`
- [turbo-tan/llama.cpp-tq3](https://github.com/turbo-tan/llama.cpp-tq3)
- Qwen3.8 27B GGUF with the bundled NextN/MTP head in `TQ3_4S`

Validated runtime build:

```text
b11174-97c631472
97c631472a6f3ecb03a9ef540a705bee33ce252f
+ 48a23e089 (turbo-tan/llama.cpp-tq3#89)
```

> **Required fix:** plain `97c631472` corrupts memory in flash attention with a
> quantized KV cache. Prompts longer than ~430 tokens (default `-ub 512`) give
> garbage output, 0% MTP acceptance, or a crash with `LLAMA_SPEC_CHAIN=1`.
> The short-prompt numbers below were unaffected, but real workloads need
> [turbo-tan/llama.cpp-tq3#89](https://github.com/turbo-tan/llama.cpp-tq3/pull/89).

### Long-output result (with the fix)

Chat endpoint, reasoning off, 839-token prompt, 4096 generated tokens,
`temperature=0`, 1 warmup + 2 measured runs, fused chain depth 2, 32K, TQ3 KV:

| Mean decode | Run 1 | Run 2 | MTP acceptance |
| ---: | ---: | ---: | ---: |
| **65.08 tok/s** | 64.91 tok/s | 65.26 tok/s | 5018/6340 = 79.1% |

## Launch

```bash
export LLAMA_SERVER_BIN=/path/to/llama-server
./launch.sh /path/to/Qwen3.8-27B-TQ3_4S.gguf
```

Equivalent command:

```bash
LLAMA_SPEC_CHAIN=1 llama-server \
  -m /path/to/Qwen3.8-27B-TQ3_4S.gguf \
  --host 0.0.0.0 --port 8190 \
  -c 32768 -np 1 -ngl 99 -fa on --jinja \
  -ctk tq3_0 -ctv tq3_0 \
  --spec-type draft-mtp --spec-draft-n-max 2 \
  --no-backend-sampling \
  --spec-draft-backend-sampling
```

`LLAMA_SPEC_CHAIN=1` enables the fused Qwen MTP chain. Both sampler flags are explicit. `--no-backend-sampling` applies to target-model
verification. `--spec-draft-backend-sampling` keeps the MTP draft sampler on the
GPU.

## Measured result

Each configuration used three or five repeated requests with the same 22-token
prompt, 128 generated tokens,
`temperature=0`, `seed=42`, disabled prompt caching, and non-streaming output.

| Configuration | Context | Decode mean | Steady final run | MTP acceptance | Output |
| --- | ---: | ---: | ---: | ---: | --- |
| fused chain, depth 2, target CPU / draft GPU | 32K | **57.384 tok/s** | **58.130 tok/s** | **67/116 = 57.76%** | deterministic |
| fused chain, depth 2, target CPU / draft GPU | 262K | 56.169 tok/s | 57.004 tok/s | 67/116 = 57.76% | deterministic |
| fused chain, depth 3, target CPU / draft GPU | 262K | 53.516 tok/s | 53.815 tok/s | 76/153 = 49.67% | deterministic |
| unfused, depth 3, target CPU / draft GPU | 262K | 49.254 tok/s | 49.446 tok/s | 375/775 = 48.39% | deterministic |
| unfused, depth 3, target GPU / draft GPU | 262K | 46.168 tok/s | 42.288 tok/s | 349/843 = 41.40% | variable |

The fused two-token chain at 32K improves the prior steady result by 17.56%.
At 262K it retains nearly all of the gain while preserving the long context.
Depths 4 and 5 were slower because the extra draft work was not accepted often
enough. Target sampling remains on the CPU because target backend sampling with
multi-output verification reduced acceptance and broke fixed-seed determinism.

A target-GPU control with speculation disabled was deterministic across five
runs. The observed problem is therefore specific to target backend sampling
combined with multi-output speculative verification, rather than a general MTP
head or backend-sampling failure.

Raw samples are stored in [`results/`](results/).

## Smoke test

```bash
curl -s http://127.0.0.1:8190/completion \
  -H 'Content-Type: application/json' \
  -d '{
    "prompt": "Write a numbered list of practical ways to reduce latency in local language-model inference. Continue until the token limit.",
    "n_predict": 128,
    "temperature": 0,
    "seed": 42,
    "cache_prompt": false,
    "stream": false
  }'
```

Check `timings.predicted_per_second`, `timings.draft_n`, and
`timings.draft_n_accepted`. Repeat the request at least five times for promotion evidence. Fixed-seed
output and acceptance should remain stable.

These figures are specific to the listed model, build, GPU, context, and request.
Re-run the same matrix after changing any of them.
