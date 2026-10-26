# Framework Spike Comparison

**Date:** 2026-10-26 · **Status:** Draft for owner review · **Question:** can an eval framework wrap the pilot's existing cases and oracles, and what does it add over the custom runner?

Evidence tags: **[M]** measured from files under `results/frameworks/` or the code in `frameworks/`; **[J]** judgement by the drafting assistant from reading that code and output; **[X]** not examined in this spike.

## Executive summary

All four frameworks (pytest, DeepEval, Inspect AI, Promptfoo) were able to launch the same OpenHands runs and report the same oracle outcomes, each in 13 to 52 lines of adapter code on top of a shared 51-line core. [M] The oracle logic stayed in the custom runner (`scripts/run_pilot.py`); the frameworks supplied the test-case iteration, repeat handling and their own report format. [M]

- **Detection result reproduced:** every framework set showed luna passing and nano failing on P-01, P-02 and P-04, so the injection would have been detected through any of them. [M]
- **No framework replaced the custom harness.** The spike measured the *wrapping* layer, not the frameworks' own strengths (LLM-judge metrics, sandboxes, red-team generators). Those were not used. [J]
- **The same data gave different headline numbers** because each framework treats the "not exercised" result differently (skip, fail, or no answer). That is a design lesson in its own right. [M]
- **Recommendation (opinion [J]):** keep the custom runner as the source of truth. If one framework is added for reporting and repeat runs, Inspect AI is the closest conceptual match for sandboxed agent tasks and pytest is the lowest-friction match for CI. Neither is a proven recommendation after one spike. See the recommendation document.

*Before sharing outside the project team, please review and validate this draft.*

## 1. What was run

| Framework | Version | Adapter | Runs | Wall time (log) |
|---|---|---|---:|---|
| pytest | 9.1.1 | `frameworks/pytest_harness/test_pilot.py` (19 lines) | 36 | 980 s in the JUnit report |
| DeepEval | 4.3.1 | `frameworks/deepeval_spike/test_pilot_deepeval.py` (52 lines) | 36 | 1004 s in the JUnit report |
| Inspect AI | 0.3.285 | `frameworks/inspect-ai/pilot_task.py` (44 lines) | 36 | about 12.4 min (luna 8.75 + nano 3.7) |
| Promptfoo | 0.125.1 (via `npx`) | `frameworks/promptfoo/provider.py` (13 lines) + `promptfooconfig.yaml` (31 lines) | 36 | 12 m 28 s |
| Shared core | - | `frameworks/common.py` (51 lines) | - | - |

Each set covered 6 cases (P-01 to P-05b), 2 profiles (luna, nano) and 3 repeats. Versions come from the `.venv-frameworks` environment metadata and the spike script; Promptfoo's version is pinned in `results/frameworks/run_spike.ps1`. Setup time and time to first result were not recorded. [X]

**How the adapters work.** Each framework calls `common.execute(...)`, which calls the same `run_once()` used by the custom runner: read back the active profile, reset and verify the workspace, create a conversation, wait, capture events, score the oracle, write a run folder under `results/frameworks/<framework>/`. The framework then maps the oracle's classification (`pass`, `fail`, `not_exercised`) to its own result type. Because the scoring code is shared, **any difference between frameworks comes from the framework layer or from agent nondeterminism, not from different oracles**. [M]

**Launch path:** the adapters call the Agent Server API and bypass Canvas, as the custom runner does, so they differ from the earlier manual Azure runs.

## 2. Outcome comparison (same cases, same runner, fresh agent runs)

Each framework set is a separate set of 36 live agent runs, so differences in counts include agent variability, not only framework behavior.

| Framework | Luna pass / scored | Nano pass / scored | Not exercised | Native headline |
|---|---:|---:|---:|---|
| Custom runner (runs 01-03) | 16 of 16 | 5 of 14* | 6 | per-run `summary.json` |
| pytest | 16 of 16 | 6 of 16* | 4 skipped | 11 failures, 4 skipped, 21 passed (JUnit) |
| DeepEval | 18 of 18 | 4 of 15 | 3 skipped | 11 failures, 3 skipped, 22 passed (JUnit) |
| Inspect AI | 17 of 17 | 4 of 16 | 3 as `NOANSWER` | accuracy 0.944 luna, 0.222 nano (18 samples each) |
| Promptfoo | 17 of 17 | 6 of 15 | 4 counted as failed | 23 passed, 13 failed (63.9% pass) |

\*Custom runner counts exclude `run-90`. Counts use the owner-approved P-03 bytecode rescore (three runs became passes: two in the custom set and one in the pytest set); each framework's own native headline is unrescored, which is why pytest shows 11 failures there but 10 failures plus 1 rescored pass here. The custom nano count differs from the frozen scorecard (3 of 12 scored on P-01 to P-05) because this table includes P-05b. All counts [M].

**Headline numbers disagree on the same data.** Promptfoo's `equals: pass` assertion makes `not_exercised` a failure, so its pass rate treats 4 non-applicable runs as failures. pytest and DeepEval skip them. Inspect AI records them as `NOANSWER`, and its accuracy metric still counts them in the denominator (luna 17 of 18). A reader comparing the dashboards would see a luna pass rate of 1.0 in pytest and DeepEval (which skip) but 0.944 in Inspect AI and Promptfoo, for identical oracle behavior. [M]/[J]

**Nano variability across framework sets** (same condition, fresh runs): P-05b passed 2 of 3 in four sets and 0 of 3 in Inspect; P-03 passed 3 of 3 in four sets and 2 of 3 in DeepEval (after the bytecode rescore); P-01 passed 0 of 3 in four sets and 1 of 3 in Promptfoo. This is the agent's nondeterminism showing through, and it is the strongest argument for more than three runs per case. [M]

## 3. Observations against the plan's criteria

The plan's scorecard ([initial-evals-plan.md](../initial-evals-plan.md), section 5.3) weights ten criteria. This spike produced evidence for only some of them, so **no weighted total is computed**; inventing scores for unexamined criteria would overstate what was learned. Judgements below are the drafter's reading of the code and outputs.

| Criterion (plan weight) | pytest | DeepEval | Inspect AI | Promptfoo |
|---|---|---|---|---|
| Agentic fit: tool trace and workspace-state assertions (20%) | Whatever the oracle does; the framework adds nothing agent-specific [J] | Same [J] | Same. Task, solver and scorer fit "launch an agent, then score state", but the model slot held a `mockllm` placeholder, so Inspect's own agent and sandbox features were not used [M] | Same. The provider runs the agent; promptfoo only compares the returned string [M] |
| Oracle flexibility (15%) | Full: any Python [J] | Custom `BaseMetric` wrapped the oracle in about 20 lines; only the programmatic layer was used, no judge metrics [M] | Custom scorer, `NOANSWER` supported [M] | `equals` on a string only; richer assertions would need work [J] |
| Brownfield integration (15%) | Python beside an existing Python runner: direct [J] | Python: direct, with telemetry opt-out environment variables needed [M] | Python: direct [J] | Needs Node and `npx` plus a Python provider (`PROMPTFOO_PYTHON`); repo tooling is TypeScript, scripts are Python [M]/[J] |
| Judge quality tooling (10%) | [X] | Catalog of judge metrics present but **not exercised** [X] | [X] | [X] |
| Reproducibility and statistics (10%) | Parametrized repeats; no native variance statistics [J] | Parametrized repeats via pytest [M] | `--epochs 3` repeats; a per-sample log [M] | `--repeat 3` and a built-in stability report with a confidence interval per case (for example "2/3 passed, 95% CI 20.8% to 93.9%") [M] |
| CI and workflow (10%) | JUnit XML, exit codes [M] | JUnit XML via pytest [M] | `.eval` log files; CLI exit behavior not checked [M]/[X] | JSON output; exit behavior not checked [M]/[X] |
| Reporting and diffing (5%) | JUnit only; no run comparison [J] | Same as pytest here [J] | Log viewer exists; not exercised [X] | `promptfoo view` exists; not exercised [X] |
| Security and data governance (5%) | Local [J] | Telemetry had to be disabled by environment variable; see below [M] | Local logs; not otherwise checked [X] | Telemetry and update-check disabled by environment variables; sharing disabled with `--no-share` [M] |
| Developer experience (5%) | Fastest to write (19 lines) [M] | 52 lines, one custom class [M] | 44 lines, three decorators [M] | 44 lines across two languages (13 provider + 31 config) [M] |
| Maintenance and community (5%) | [X] | [X] | [X] | [X] |

**Concurrency.** All four had to run serially, because the workspaces and the global active profile are shared. The shared core uses a lock; Inspect ran with `--max-samples 1 --max-tasks 1`; Promptfoo with `-j 1`. A framework's parallelism is therefore irrelevant to this SUT unless workspaces and profiles are isolated per run. [M]

**Telemetry and data egress.** The spike script sets `DEEPEVAL_TELEMETRY_OPT_OUT`, `PROMPTFOO_DISABLE_TELEMETRY` and `PROMPTFOO_DISABLE_UPDATE`. That these were needed is relevant for confidential contexts; whether they fully prevent egress was not tested. Synthetic fixtures only were used. Involve the Data Privacy Officer before running any framework on real data. [M]/[X]

## 4. What the spike did not test

- Judge-based metrics (DeepEval, Promptfoo model-graded assertions, Inspect model scorers) and judge calibration.
- Inspect AI sandboxes and agent solvers, Promptfoo red-team generation, RAGAS (not run; `frameworks/ragas/` is empty).
- Setup time, documentation quality, license and pricing terms, release cadence.
- Whether the frameworks add value at larger scale (more cases, CI gating, historical comparison).
- Any ability to read the OpenHands event stream natively (all adapters read it through the shared runner).

## 5. Interpretation

**Technical.** For state-based oracles over a black-box agent, the oracle code is the valuable part and it is framework-independent. Frameworks mainly differ in how they surface repeats, skipped results and reports. The spike exposed one real hazard: **result semantics for "not applicable"** (skip, fail, no answer) change the headline number, so the mapping must be decided and documented once, in the shared core, not left to each framework's default.

**Business.** A framework is not required to get the pilot's evidence, and adopting one before the case set is larger would add a dependency without a demonstrated gain. The case for a framework rests on reporting, repeat statistics and CI conventions, which should be judged when the suite is bigger. [J]

**Decision implication [P]:** keep the custom runner as the reference implementation, standardize the `not_exercised` mapping, and trial one framework end to end at the next increment, with the plan's scorecard criteria scored from evidence.

## 6. Reproduce

```text
results/frameworks/run_spike.ps1      # runs pytest, DeepEval, Inspect AI and Promptfoo in turn
results/frameworks/spike-log.txt      # UTF-16 log with start/finish timestamps
python scripts/aggregate_results.py   # framework tallies in results/reports/pilot-aggregate.json
```
