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

| Benchmark | Muse 30B | 27B out6k | Notes |
|---|---:|---:|---|
| Hard86 | **74/86** ✅ | **76/86** ✅ | Same script, thinking ON temp 0, TOM system prompt. Muse −2 assertions — effectively neck-and-neck |
| HumanEval pass@1 | **93.3** ✅ | — | 27B never measured on evalplus |
| HumanEval+ pass@1 | **89.0** ✅ | — | official evalplus scorer |
| MBPP pass@1 | ⏳ | — | |
| MBPP+ pass@1 | ⏳ | — | |

Evalplus gap is real: the 27B line was validated on task-suite + Hard86 only. If the
comparison needs a 27B evalplus column, that run has to be performed (out6k GGUF is not on
the local box — it lives on the tc fleet).

## 3. Task-suite quality (task breakdown only — no overall per publication rules)

| Suite | Muse 30B | 27B out6k (2026-06-05 record) |
|---|---:|---:|
| coding | ⏳ | 100.0 |
| toolcall | ⏳ | 96.7 |
| dataextract | ⏳ | 89.1 |
| reasonmath | ⏳ | 73.3 |
| instructfollow | ⏳ | 68.9 |
| speed | ⏳ | 67.7 |

27B record = run `20260605-215446-qwen36-27b-mtp-tq3_4s-mtp-q4k-publish-full` (GB10,
openai_compat). Caveat: that run predates the June publish-template fix; the later template
fix raised instructfollow on other variants, so the 68.9 may understate current out6k.

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

## 6. Verdict (to finalize after ⏳ fields land)

Working draft: Muse-Glimmer-30B TQ3_4S lands within 2 Hard86 assertions of the established
27B out6k champion and matches our 284B-MoE flagship R2_TQ3_4S exactly on HumanEval/HE+
(93.3/89.0) — at 14 GiB, with 128K context and vision. Positioning: dense 14 GB-class
alternative to out6k with vision + longer context, pending task-suite confirmation.
