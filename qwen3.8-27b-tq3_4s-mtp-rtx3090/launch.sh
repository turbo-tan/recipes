#!/usr/bin/env bash
# Fastest validated config: DFlash2 drafter, q4_0 KV (fused flash attention), 262K context.
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 /path/to/Qwen3.8-27B-TQ3_4S-v2.gguf /path/to/Qwen3.8-27B-DFlash2-Q4_K_M.gguf" >&2
    exit 2
fi

server_bin=${LLAMA_SERVER_BIN:-llama-server}

exec "$server_bin" \
    -m "$1" \
    -md "$2" \
    --host 0.0.0.0 \
    --port 8190 \
    -c 262144 \
    -np 1 \
    -ngl 99 \
    -ngld 99 \
    -fa on \
    --jinja \
    -ctk q4_0 \
    -ctv q4_0 \
    --spec-type draft-dflash \
    --spec-draft-n-max 4 \
    --reasoning off
