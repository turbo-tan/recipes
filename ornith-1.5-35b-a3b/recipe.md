# Ornith-1.5-35B-A3B to TQ3_4S Conversion Recipe

## Source Model
- **Base**: ornith-ai/Ornith-1.5-35B-A3B
- **Architecture**: Qwen3_5MoeForConditionalGeneration (MoE, 3B active)
- **Parameters**: 35.9B total, 3B active
- **License**: Apache-2.0

## Conversion Steps

### Step 1: Download Safetensors
```bash
cd ~/models
hf download ornith-ai/Ornith-1.5-35B-A3B --local-dir ./Ornith-1.5-35B-A3B
```

### Step 2: Convert to GGUF F16
```bash
cd ~/code/llama.cpp-tq3
source .venv/bin/activate

python convert_hf_to_gguf.py \
  /home/awee/models/Ornith-1.5-35B-A3B \
  --outfile /home/awee/models/Ornith-1.5-35B-A3B-F16.gguf \
  --outtype f16
```

### Step 3: Quantize to TQ3_4S
```bash
./build/bin/llama-quantize \
  /home/awee/models/Ornith-1.5-35B-A3B-F16.gguf \
  /home/awee/models/Ornith-1.5-35B-A3B-TQ3_4S.gguf \
  tq3_4s
```

## Runtime Configuration

Validated on RTX 3090 (24GB VRAM):

```bash
./build/bin/llama-server \
  -m Ornith-1.5-35B-A3B-TQ3_4S.gguf \
  --alias Ornith-1.5-35B-A3B-TQ3_4S \
  --host 127.0.0.1 --port 8080 \
  -c 32768 -np 1 -ngl 99 -fa on \
  -ctk q8_0 -ctv tq3_0 \
  --reasoning-budget 8192 \
  --jinja
```

### Key Parameters
- `-fa on`: Flash attention enabled
- `-ctk q8_0`: Key cache quantization (q8_0)
- `-ctv tq3_0`: Value cache quantization (tq3_0)
- `--reasoning-budget 8192`: Thinking token budget
- `-ngl 99`: Full GPU offload
- `-c 32768`: 32K context window

## Expected Results

Based on Ornith-1.0-35B-TQ3_4S (previous generation):
- **Size**: ~13GB (F16) → ~4-5GB (TQ3_4S)
- **Generation speed**: ~146 tok/s on RTX 3090
- **Hard86**: ~81%

For MoE model (3B active), expect:
- Faster generation (less active compute)
- Similar memory footprint
- Potentially better code quality (newer training)

## Validation Checklist
- [ ] Model loads without errors
- [ ] Smoke test passes (responds to simple prompts)
- [ ] Three.js generation quality verified
- [ ] Benchmark results recorded
- [ ] Model card created with same structure as Ornith-1.0-35B-TQ3_4S

## Notes
- This is Ornith 1.5 (newer than 1.0)
- MoE architecture with 3B active parameters
- Should be faster than dense 35B models
- Vision capabilities if mmproj is available
