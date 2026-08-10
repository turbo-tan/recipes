#!/usr/bin/env bash
# R2/v9a — local 3090 @512K decode + gate
# Prepared 2026-08-10. HOLD: do not run until llama.cpp-tq3 main is sorted
# (binary must be built from the settled main; local clone not rebuilt since repair).
#
# Base config: recipes/v9a README "local 3090 @1M" recipe, verified 14.19 t/s @1M.
# Only change: -c 1048576 -> -c 524288 (KV compressed ctk q4_0 / ctv tq3_0 makes
# context nearly free: measured ±3% across 128K/512K/1M).
# Target comparison: Spark v9a @512K = 18.9-21.4 t/s.
set -euo pipefail

REPO=~/code/llama.cpp-tq3
BINARY=${BINARY:-$REPO/build-current/bin/llama-server}
MODEL=~/models/deepseek-v4-flash/DeepSeek-V4-Flash-0731-TQ3_4S_v9a.gguf
PORT=${PORT:-8086}
OUT=~/code/recipes/v9a/results/local-512k-3090
KEEP=${KEEP:-0}   # KEEP=1 to leave server running after benchmark
mkdir -p "$OUT"

echo "== binary: $BINARY"
echo "   built: $(stat -c '%y' "$BINARY" | cut -d. -f1)"
echo "   REBUILD FROM SETTLED MAIN FIRST IF STALE"

# --- launch (mlock requires root; pin full 91 GB) ---
sudo -n bash -c "ulimit -l unlimited; exec '$BINARY' \
  -m '$MODEL' \
  --host 127.0.0.1 --port $PORT \
  -c 524288 -np 1 \
  -ngl 44 --n-cpu-moe 39 --load-mode mmap+mlock \
  -fa on -ctk q4_0 -ctv tq3_0 \
  --reasoning on --reasoning-budget 256 --reasoning-format deepseek --jinja \
  -t 16 -tb 16 -b 8192 --fit on" \
  > "$OUT/server.log" 2>&1 &
SRV_PID=$!
echo "$SRV_PID" > "$OUT/server.pid"

echo "== waiting for load (91 GB mmap+mlock, ~2-4 min)..."
for i in $(seq 1 240); do
  sleep 2
  if curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/health" 2>/dev/null | grep -q 200; then
    echo "   healthy after $((i*2))s"; break
  fi
  if ! kill -0 "$SRV_PID" 2>/dev/null; then
    echo "SERVER DIED — see $OUT/server.log"; tail -20 "$OUT/server.log"; exit 1
  fi
done

# --- gate: arithmetic with thinking ON (budget-256 trap: give >=320 tokens) ---
echo "== gate: 6x arithmetic, thinking ON =="
PASS=***
for q in "17 * 23" "48 * 73" "156 + 287" "913 - 468" "21 * 60" "144 / 12"; do
  ANS=$(curl -s "http://127.0.0.1:$PORT/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"r2\",\"messages\":[{\"role\":\"user\",\"content\":\"What is $q? Answer with just the number.\"}],\"max_tokens\":320}" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['choices'][0]['message']['content'].strip()[:40])")
  EXPECTED=$(python3 -c "print(eval('${q//x/*}'))")
  if echo "$ANS" | grep -q "$EXPECTED"; then PASS=*** echo "  $q = $ANS  OK"; else echo "  $q = $ANS  FAIL (expected $EXPECTED)"; fi
done
echo "gate: $PASS/6"

# --- decode: 3 runs x 1024 tokens (compare vs 14.19 @1M, Spark 18.9-21.4 @512K) ---
echo "== decode: 3 x 1024 tok =="
python3 - "$PORT" "$OUT" <<'EOF'
import json, sys, time, urllib.request
port, out = sys.argv[1], sys.argv[2]
runs = []
for i in range(3):
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}/completion",
        data=json.dumps({
            "prompt": "Write a detailed, factual essay about the history of distributed computing, covering the major milestones.",
            "n_predict": 1024, "temperature": 0.7}).encode(),
        headers={"Content-Type": "application/json"})
    t0 = time.time()
    d = json.load(urllib.request.urlopen(req, timeout=600))
    wall = time.time() - t0
    api = d["timings"]["predicted_ms"] / 1000
    tps = d["tokens_predicted"] / api if api > 0 else 0
    runs.append({"tokens": d["tokens_predicted"], "wall_s": round(wall, 1),
                 "api_s": round(api, 1), "decode_tps": round(tps, 2)})
    print(f"  run{i+1}: {runs[-1]['tokens']} tok / {runs[-1]['api_s']}s = {runs[-1]['decode_tps']} t/s")
avg = round(sum(r["decode_tps"] for r in runs) / len(runs), 2)
print(f"  avg: {avg} t/s")
json.dump({"config": "local 3090, R2 v9a, 512K ctx, no drafter, budget 256",
           "runs": runs, "avg_decode_tps": avg},
          open(f"{out}/decode_speed.json", "w"), indent=1)
EOF

echo "gate: $PASS/6" | tee "$OUT/gate.txt"

# --- cleanup (KEEP=1 to leave server up) ---
if [ "$KEEP" = "1" ]; then
  echo "== server kept running on :$PORT (pid $SRV_PID)"
else
  sudo -n kill "$SRV_PID" 2>/dev/null || kill "$SRV_PID" 2>/dev/null || true
  sleep 5
  echo "== server stopped; results in $OUT"
fi
