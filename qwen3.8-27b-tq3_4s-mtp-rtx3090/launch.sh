#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 /path/to/Qwen3.8-27B-TQ3_4S.gguf" >&2
    exit 2
fi

model_path=$1
server_bin=${LLAMA_SERVER_BIN:-llama-server}

LLAMA_SPEC_CHAIN=1 exec "$server_bin" \
    -m "$model_path" \
    --host 0.0.0.0 \
    --port 8190 \
    -c 32768 \
    -np 1 \
    -ngl 99 \
    -fa on \
    --jinja \
    -ctk tq3_0 \
    -ctv tq3_0 \
    --spec-type draft-mtp \
    --spec-draft-n-max 2 \
    --no-backend-sampling \
    --spec-draft-backend-sampling
