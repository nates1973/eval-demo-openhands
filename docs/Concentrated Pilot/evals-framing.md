# How the Concentrated Pilot Relates to Evals

> **Updated 2026-10-26.** Written on 2026-10-21 when the pilot was still manual. The text below is preserved as the original framing; the [Update 2026-10-26](#update-2026-10-26-status-of-the-runner-injection-and-framework-spike) section at the end records what became of each gap and plan item.

**Date:** 2026-10-21 · **Status:** Framing for the team. Framework statements are general knowledge and **not verified against current documentation**; verify before relying on them.

## What this pilot is

A small, custom, **outcome-based agent eval** run by hand. OpenHands is the system under test (SUT). Each case gives the agent a task in a pinned synthetic repository, and the result is scored by checking the **final state and measurable facts**, not by trusting the agent's own account.

It is not a framework-managed evaluation. There is no automated runner, CI job, judge model or published benchmark. See the [charter](./experiment-charter-2026-10-19.md) and [pilot results report](./pilot-results-and-meeting-report.md).

## Mapping to general eval concepts

| Eval concept | In this pilot | Where |
|---|---|---|
| Dataset / cases | Five versioned cases (P-01 to P-05) with pinned fixtures and expected results | `dataset/cases/pilot-cases.jsonl`, `dataset/cases/expected-results/` |
| System under test | OpenHands Agent Server on Azure, driven through Canvas | `config/`, charter addenda |
| Task input | The case prompt, sent unchanged | `prompt` in each case |
| Environment / sandbox | Container workspace on a persistent share, reset to a known commit | `/project/qa-repo-p01-v11`, `reset_command` |
| Scorer / oracle | Programmatic: git diff scope, file hashes, test exit code and counts, expected failing test, firewall log | `assertions`, `oracle_types` |
| Controls | Fixed model profile, preflight snapshot, egress limited to Azure OpenAI, fixed iteration cap | `preflight.json`, firewall |
| Metrics | Pass or fail, actions, tokens, cost, classification of infrastructure failures | `results/runs/*/summary.json` |
| Regression detection | Planned Friday test: swap the model and see whether the suite notices | [concentrated-plan.md](./concentrated-plan.md) |

## Kinds of checking used

- **Executable oracle:** run the documented tests and compare exit code and counts.
- **Structural oracle:** diff and hash checks for allowed or forbidden changes.
- **Honest reporting:** compare the agent's claims with the observed facts.
- **Infrastructure classification:** provider, auth or routing failures are not scored as agent failures.

Not covered: LLM-as-judge grading, repeated-trial statistics, multi-turn user simulation, trajectory or tool-call scoring, and production data.

## Current gaps relative to a framework

| Gap | Effect |
|---|---|
| `assertions` are labels only; no code reads them | Scoring is manual and repeatable only by procedure |
| No runner | Runs start by hand in Canvas |
| No raw event capture saved | Evidence is summaries plus queries of the Agent Server |
| Single run per case and model | No noise-floor estimate |
| Agent-reported test results in some runs | Not independently rerun |

## Plan for framework use

1. **Now:** finish the manual pilot (P-02 to P-05, baseline, Friday injection) using the controls above.
2. **If time allows, at the end:** a bounded spike using **Inspect AI**, with **Promptfoo** as an optional comparison.
   - Start with P-02 (deterministic, no edits).
   - Write a thin adapter that starts an OpenHands conversation through the Agent Server API and waits. Scorers reuse the existing checks (diff scope, hashes, test exit code).
   - Compare the framework's results with the manual records.
   - Record that the adapter bypasses Canvas, so it is a different launch path from the manual runs.
3. **Before the spike:** verify each framework's current documentation for agent or sandbox support, scorer APIs and how to call an external service. Record the versions used.

## How to present it

"We ran a custom, state-based agent eval with controlled fixtures and programmatic oracles, and used it to detect an injected change. A framework would automate the runner, logging and repeat runs; we are testing whether one can wrap the same cases." Do not claim the manual pilot is framework-based, benchmarked, or statistically meaningful.

## Update 2026-10-26: status of the runner, injection and framework spike

**Gaps table, current status**

| Gap (10-21) | Status on 10-26 |
|---|---|
| `assertions` are labels only; no code reads them | Closed for local runs: `scripts/run_pilot.py` evaluates the assertions in code. |
| No runner | Closed: the runner drives the Agent Server API, bypassing Canvas. This is a different launch path from the earlier manual Azure runs. |
| No raw event capture saved | Closed for local runs (`events.json` per run). |
| Single run per case and model | Closed for the local sets: 3 planned runs per case per model (plus one extra luna run per case), still a pilot sample, not a confidence interval. |
| Agent-reported test results in some runs | Closed for local runs, where the oracle is rerun from the workspace. Open for the earlier Azure runs. |

**Plan items, current status**

- **Regression detection (planned Friday test):** run on 2026-10-26 on a local deployment by substituting `gpt-4.1-nano` for `gpt-5.6-luna`. The verdict against the frozen red criteria is **Detected**; see [pilot-scorecard-and-verdict.md](./pilot-scorecard-and-verdict.md).
- **Environment change:** the Azure instance became unreachable on 10-22, so the baseline and injection ran locally. Mapping table rows referring to Azure, `/project/...` and the firewall describe the Azure runs only. See the [charter addendum](./experiment-charter-2026-10-19.md) and [Azure Environmental Impacts](./Azure%20Environmental%20Impacts.md).
- **Framework spike (plan item 2):** executed on 2026-10-26. The original plan was Inspect AI first, starting with P-02, with Promptfoo optional. As run, the spike covered **Inspect AI, Promptfoo, pytest and DeepEval**, all six cases, both models and three runs each, through a shared adapter (`frameworks/common.py`) that reuses the runner's scorers, so differences come from the framework layer. RAGAS was not run (`frameworks/ragas/` is empty). The expansion beyond the original scope was an owner decision on the day. Results are in `results/frameworks/`; the comparison is in [framework-spike-comparison.md](./framework-spike-comparison.md).
- **Framework documentation check:** the "before the spike" step (verify current docs, record versions) is only partly recorded: Promptfoo ran as `promptfoo@0.125.1` (from the spike script). Versions from the spike environment: pytest 9.1.1, DeepEval 4.3.1, Inspect AI 0.3.285.

**Still valid:** the caution that framework statements above are general knowledge, not verified against current documentation, and the presentation guidance. The final claim to avoid remains "framework-based or statistically meaningful": the spike wrapped the same custom cases and scorers rather than replacing them.
