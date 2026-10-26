# Concentrated OpenHands Evals Pilot: Index

**Status as of 2026-10-26:** executed and documented; the owner's decision on the recommendation and the presentation are pending.
**Claim tested:** a small black-box eval suite can reveal meaningful differences in OpenHands behavior and catch an externally introduced regression.
**Result:** **Detected** (model substitution, luna to nano), on the synthetic pilot benchmark. Proposed decision: **Continue**, with the identified refinements as the next increment's first tasks.

All documents here are drafts for owner review. Results are small-sample pilot counts on synthetic tasks, not production evidence, and not an official company statement. Review and validate before sharing outside the project team.

## Read in this order

| # | Document | What it answers |
|---|---|---|
| 1 | [pilot-recommendation-and-presentation-outline.md](./pilot-recommendation-and-presentation-outline.md) | What should we do next? Includes the 7-slide outline |
| 2 | [pilot-scorecard-and-verdict.md](./pilot-scorecard-and-verdict.md) | What were the results, and was the regression detected? |
| 3 | [pilot-findings.md](./pilot-findings.md) | What did we learn, in technical and business terms? |
| 4 | [framework-spike-comparison.md](./framework-spike-comparison.md) | What happened when four eval frameworks wrapped the same cases? |

## Background and decision record (kept as written, with dated updates)

| Document | Role |
|---|---|
| [concentrated-plan.md](./concentrated-plan.md) | The one-week plan, with an execution status and deviations section added at the end |
| [experiment-charter-2026-10-19.md](./experiment-charter-2026-10-19.md) | Hypothesis, environment, cases, scoring rules. Addenda record the 10-21 changes, the frozen red criteria (b) and the 10-26 move to local |
| [evals-framing.md](./evals-framing.md) | How the pilot relates to eval concepts and frameworks; update records status |
| [pilot-results-and-meeting-report.md](./pilot-results-and-meeting-report.md) | Snapshot of the first Azure runs (Oct 19), with an update section |
| [provider-routing-impact-assessment.md](./provider-routing-impact-assessment.md) | The provider-routing problem and its effect on the plan |
| [Azure Environmental Impacts.md](./Azure%20Environmental%20Impacts.md) | Why the Azure path was suspended, the evidence, and re-entry criteria |
| [provider configuration issue.txt](./provider%20configuration%20issue.txt) | External guidance on provider configuration (not confirmed as the cause) |
| [../initial-evals-plan.md](../initial-evals-plan.md) | The full eight-week study design the pilot is a slice of |
| [../initial-evals-report.md](../initial-evals-report.md) | Assessment of the OpenHands Canvas repository |

## Key numbers (all [M], regenerable)

| Measure | Value |
|---|---|
| Baseline (luna), frozen design | 15 of 15 pass |
| Injected (nano), frozen design | 3 of 15 pass; 9 failed; 3 `not_exercised`; 12 valid scored (P-03 bytecode rescored; strict scoring: 1 pass, 11 failed) |
| Red criteria fired | Task-success drop (9 vs threshold 3); runaway (1 iteration-cap run). Mutation, secret disclosure and honest-report failure did not fire in the frozen set |
| Supplementary secret-handling and mutation signal (logged in the charter) | nano 6 of 12 scored P-05b runs leaked or copied the canary and 1 P-03 run edited a test file; luna none |
| Local runs | 42 main, 144 framework, 12 side; no invalid local run |
| OpenHands-recorded model cost, all local runs | $0.85 (not billing-verified) |

## Where the evidence lives

| Path | Contents |
|---|---|
| `dataset/cases/` | Case definitions (`pilot-cases.jsonl`), expected results, local workspace baselines |
| `dataset/fixtures/` | Three synthetic fixture repositories |
| `scripts/run_pilot.py` | The custom runner: preflight, reset, run, capture, score |
| `scripts/aggregate_results.py` | Rebuilds every figure; writes `results/reports/pilot-aggregate.json` |
| `results/runs/` | Azure runs (10-19 to 10-21) and local runs (`2026-10-26_local_*`) |
| `results/frameworks/`, `frameworks/` | Framework spike results and adapters |
| `results/side-conditions/` | Exploratory runs outside the frozen design |
| `results/verification/` | Deployment and preflight snapshots |

## Reproduce the figures

```text
python scripts/aggregate_results.py
```

Raw event logs (`events.json`) are in the run folders and are **not** covered by a `.gitignore` rule (checked with `git check-ignore`). They contain agent output and the synthetic canary; review and scrub them before committing or sharing, per the repository rule against committing unscrubbed logs.

## Reading rules

- **Frozen design** means luna and nano runs 01-03 on P-01 to P-05 (plus P-05b for some criteria). Everything else is supplementary or exploratory and is labeled so.
- Azure (Agent Server 1.54.0) and local (1.58.1) runs are different environments and are not pooled.
- **[M]** measured from files; **[J]** judgement; **[P]** proposed; **[R]** reported, unverified.

## Open items

See the scorecard (section 8) and the recommendation (section 1.6). Notably: manual review of pattern-scored items (`run-90` is unexplained and excluded; the P-03 bytecode rescore and the leak-evidence addendum are done), Azure teardown record, and a check of untracked files for sensitive content before any commit.
