# Muse-Glimmer-30B TQ3_4S vs Qwen3.6-27B-MTP TQ3_4S (out6k) — DRAFT

Status: DRAFT — evalplus MBPP and Muse task-suite still running. Numbers marked ✅ are measured;
⏳ pending; — = never measured (do not fabricate).

## 1. What's being compared

| | Muse-Glimmer-30B TQ3_4S | Qwen3.6-27B-MTP TQ3_4S (out6k) |
|---|---|---|
| Family | Muse-Glimmer (meta-models), dense | Qwen3.6-27B with MTP draft head |
| Quant | TQ3_4S, 4.25 bpw (out6k recipe: output/embd q6_K) | TQ3_4S-mtp-q4k-outq6 |
| Size | 13.78 GiB | 14 GiB (13.39 GiB) |
| Context | 131,072 (GGUF metadata) | 32,768 served in benches |
| Vision | yes (mmproj) | no |
| Spec decoding | DFlash external drafter (1.6 GB) | MTP built-in head |
| Parent license | apache-2.0 | (Qwen license) |

Nearly identical footprint (14 GiB class), so the comparison is a fair size-class matchup.

## 2. Coding quality (same harness = comparable)

| Benchmark | Muse 30B TQ3_4S | 27B out6k | Notes |
|---|---:|---:|---|
| Hard86 | 74/86 (86.0%) ✅ | 76/86 (88.4%) ✅ | Same harness. Muse −2 assertions |
| HumanEval pass@1 | **93.3** ✅ | — (only + recorded) | |
| HumanEval+ pass@1 | 89.0 ✅ | **92.7** ⚠️ | 27B via vLLM-nvfp4, flagged directional |
| MBPP pass@1 | **89.7** ✅ | — (only + recorded) | |
| MBPP+ pass@1 | 74.6 ✅ | **87.8** ⚠️ | 27B via vLLM-nvfp4, flagged directional |

27B source: `ai_workspace/publish/laguna-xs-2.1-tq3_4s/four_way_compare.html` (2026-07-31/08-01).
Its own footnote: evalplus = greedy pass@1, 27B served via vLLM-nvfp4, marked *directional* —
different serving stack than the Muse GGUF numbers, so treat deltas as indicative, not final.

## 3. Task-suite quality (task breakdown only — no overall per publication rules)

| Suite | Muse 30B | 27B out6k (Jun 13 record) |
|---|---:|---:|
| coding | 87.5 (10/12) | **100.0** (12/12) |
| toolcall | 80.0 (11/15) | **96.7** (14/15) |
| dataextract | 82.8 (9/15) | **91.0** (12/15) |
| reasonmath | **80.0** (12/15) | 73.3 (11/15) |
| instructfollow | **96.7** (14/15) | 74.5 (9/15) |
| speed | **70.8** (9/9) | 68.6 |

Muse config: RTX 3090, DFlash n_max=3, reasoning_strength=low, gen 47.9 tok/s.
27B record: gated results Jun 13 (recipe doc), publish template, GB10, MTP spec decode,
gen 42.73 tok/s. Suite definitions identical both sides; hardware/drafter differ.

## 4. Speed (NOT cross-comparable — listed per-model only)

Speed comparisons across these two would conflate drafter type (DFlash vs MTP), hardware
(GB10 vs 3090), and config. Report each model's own numbers with full config stated:

| Config | Muse 30B (RTX 3090, 8K ctx) | 27B out6k (record) |
|---|---:|---:|
| llama-bench pp2048 | 1,155 t/s ✅ | — |
| llama-bench tg128 | 43.25 t/s ✅ | — |
| decode, no drafter | 44.64 t/s ✅ (8K) | — |
| decode, best drafter | 53.69 t/s ✅ (DFlash n_max=3, 8K) | ~54 t/s (MTP, GB10, 32K) |
| task-suite gen tok/s | ⏳ | 35.5 (GB10, MTP) |

Model-card wording: state decode with context + drafter config explicitly, never a bare
"Muse is faster/slower than 27B" claim.

## 5. Fairness ledger (for the write-up)

Comparable: Hard86 (same harness), evalplus methodology (official scorer), task-suite suite
definitions.
Not comparable: speed across hardware/drafter; the 27B task-suite record's age/template;
27B has no evalplus record.
Losslessness note: speculative decoding (DFlash or MTP) does not change output quality —
quality numbers above are drafter-independent.

## 6. Verdict

Muse-Glimmer-30B TQ3_4S is a **different profile, not a replacement** for 27B out6k:

- **Muse wins:** instructfollow 96.7 vs 74.5 (+22), reasonmath 80.0 vs 73.3, speed suite
  70.8 vs 68.6, and it matches R2_TQ3_4S (284B-MoE) exactly on HumanEval/HE+ (93.3/89.0).
- **27B out6k wins:** coding 100 vs 87.5, toolcall 96.7 vs 80.0, dataextract 91.0 vs 82.8,
  HE+ 92.7 vs 89.0, MBPP+ 87.8 vs 74.6 (⚠️ directional vLLM-nvfp4), Hard86 76 vs 74.
- **Muse-only extras:** vision (mmproj), 128K native context, dense architecture (no MTP head).

Positioning: at the same 14 GiB footprint, Muse is the **instruction-following + reasoning
generalist with vision and long context**; out6k remains the **coding/agentic specialist**.
