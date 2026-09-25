#!/usr/bin/env python3
import json, statistics, sys, time, urllib.request
PORT = int(sys.argv[1]); LABEL = sys.argv[2]; OUT = sys.argv[3]
EP = f"http://127.0.0.1:{PORT}/v1/chat/completions"
FILLER = ("In a distributed task scheduler, each worker maintains a local priority queue and "
          "supports checkpointing, backpressure, at-least-once delivery, leader election via "
          "heartbeats, and graceful drain. Retries use exponential backoff with jitter, and "
          "poison messages are routed to a dead-letter topic. Metrics are exported per shard. ")
PROMPT = FILLER * 12 + ("\n\nImplement this complete system as a single self-contained Python module: all classes, "
                        "full method bodies, docstrings, type hints, and a comprehensive unittest suite at the end. "
                        "Write everything in full. No reasoning commentary, only code.")
def run():
    body = json.dumps({"messages": [{"role": "user", "content": PROMPT}],
                       "temperature": 0, "max_tokens": 4096}).encode()
    d = json.load(urllib.request.urlopen(urllib.request.Request(EP, data=body, headers={"Content-Type": "application/json"}), timeout=1800))
    t = d["timings"]
    return dict(tps=t["predicted_per_second"], n=d["usage"]["completion_tokens"], prompt=d["usage"]["prompt_tokens"],
                draft=t.get("draft_n"), acc=t.get("draft_n_accepted"))
w = run(); print("warmup", w, flush=True)
rs = [run() for _ in range(2)]
for r in rs: print("run", r, flush=True)
res = dict(label=LABEL, warmup=w, runs=rs, mean=round(statistics.mean(r["tps"] for r in rs), 2),
           acceptance=round(sum(r["acc"] for r in rs) / sum(r["draft"] for r in rs), 3))
print("RESULT", json.dumps(res), flush=True)
open(OUT, "a").write(json.dumps(res) + "\n")
