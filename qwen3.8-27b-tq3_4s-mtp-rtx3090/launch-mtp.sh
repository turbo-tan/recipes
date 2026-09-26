#!/usr/bin/env bash
# No separate drafter: the model's built-in MTP head, fused chain depth 3, q4_0 KV, 262K context.
# Optional: DRAFT_VOCAB_MAP=/path/to/map.txt restricts draft sampling to a token subset (used for the 107.9 tok/s run).
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 /path/to/Qwen3.8-27B-TQ3_4S-v2.gguf" >&2
    exit 2
fi

server_bin=${LLAMA_SERVER_BIN:-llama-server}
map_args=()
[[ -n ${DRAFT_VOCAB_MAP:-} ]] && map_args=(--spec-draft-vocab-map "$DRAFT_VOCAB_MAP")

LLAMA_SPEC_CHAIN=1 exec "$server_bin" \
    -m "$1" \
    --host 0.0.0.0 \
    --port 8190 \
    -c 262144 \
    -np 1 \
    -ngl 99 \
    -fa on \
    --jinja \
    -ctk q4_0 \
    -ctv q4_0 \
    --spec-type draft-mtp \
    --spec-draft-n-max 3 \
    "${map_args[@]}" \
    --no-backend-sampling \
    --spec-draft-backend-sampling \
    --reasoning off
