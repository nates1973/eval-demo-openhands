# Pilot Recommendation and Presentation Outline

**Date:** 2026-10-26 · **Status:** Draft for owner decision and review. **Revised 2026-10-26:** the decision changed from "Refine, then continue" to "Continue" after the owner asked whether the refinements strengthen the pilot's findings (see section 1.1). · **Audience:** the project owner first; then the pilot meeting audience (mixed technical and business).

The recommendation below is **proposed by the drafting assistant [P]**. The decision belongs to the project owner. Slide content cites [pilot-scorecard-and-verdict.md](./pilot-scorecard-and-verdict.md), [pilot-findings.md](./pilot-findings.md) and [framework-spike-comparison.md](./framework-spike-comparison.md). Review and validate all figures before presenting externally.

## Executive summary

**Proposed decision: Continue** (to the next increment, with the refinements below built into its first tasks). Of the plan's three options (Continue, Refine, Stop or redirect), the evidence supports **Continue**; an earlier draft proposed Refine, and section 1.1 explains why that was changed:

- The suite **detected** the injected regression clearly (verdict: Detected), with executable and structural oracles producing nearly all the evidence. That supports continuing.
- The baseline is **saturated** (75 of 75 pooled luna passes on P-01 to P-05), the secret-handling case has a known **exposure-detection gap**, and the honest-report check **never fired**. Those limit what the next stage can claim, and are the first tasks of the next increment. They do not weaken the pilot's own conclusion.

The plan's "Continue" criterion holds as written: "The suite produced meaningful findings and detected the injected regression."

## 1. Recommendation

### 1.1 Decision

**Continue to the next increment.** [P] The owner asked whether the proposed refinements improve the overall strength of the findings. My assessment [J]:

- **For the pilot's findings, mostly no.** The verdict (Detected) rests on criteria 4 and 5 and holds under strict or rescored scoring (9 or 11 more failures than baseline against a threshold of 3). Fixing the exposure check, the command-string check or the case set would not change it. The one refinement that did bear on the data (ignoring bytecode in P-03) is cheap, was applied retroactively by rescoring, and is already reflected in the scorecard.
- **For the next increment, yes.** A saturated baseline, an exposure check that undercounts reads and an over-strict command check would be copied into a larger suite and weaken what it can claim. So they belong at the start of the next increment as its entry tasks, not as a separate gate before it.
- **Therefore Continue**, not Refine: the refinements are planned work inside the next increment, not a precondition for treating the pilot as complete.

### 1.2 Why not the alternatives

| Option | Assessment |
|---|---|
| **Continue** | The detection result is solid and does not depend on the refinements. Recommended, with the refinements as the next increment's first tasks. |
| Refine first | Would delay the next stage without changing the pilot's conclusion. Not recommended. |
| Stop or redirect | The cases provided actionable evidence (T1, T2, T6), so this is not supported. |

### 1.3 Refinements to build into the start of the next increment (in priority order)

1. **Exposure detection for injection cases.** Record file reads from the action stream (command text) as well as observation text, so `not_exercised` stops hiding real reads (finding T6, caveat C2).
2. **Scope oracle.** Ignore bytecode in the runner's scope check going forward. The pilot data are already rescored (owner decision, T5, C1).
3. **Command-string check.** Accept equivalent test invocations for P-02 and P-04 (T2).
4. **Un-saturate the baseline.** Add harder or ambiguous cases, including one with an unfixable failure to give an agent a reason to over-claim (T4, T7). Track actions, tokens and duration as secondary signals.
5. **Freeze the `not_exercised` and skip semantics once**, in the shared core, so every report treats them the same way (framework doc, section 2).
6. **Manual review of pattern-scored items** (`needs_manual_review`) for a sample of luna runs and all red-signal runs.
7. **Housekeeping:** stop using the `run-90` numbering (no one recorded why it was used; it looks like a pre-run shakedown sweep), log the final active profile after an injection, and verify cost against billing before quoting dollars.

### 1.4 Next increment (adapted from the plan's slide 7)

| Item | Proposed scope |
|---|---|
| Cases | Expand from 5 to about 12, with distinct oracle types; keep the five pilot cases for continuity |
| Repeats | Increase to k=5 (the plan's baseline starting point); report per-case counts, not rates alone |
| Injections | Add one **held-out** injection with a subtler effect than model substitution (for example a changed default or approval mode, or a nearer-capability model). Freeze its red criteria before running it |
| Framework | Trial **one** framework against the custom harness, scoring the plan's section 5.3 criteria from evidence. Candidates: Inspect AI (closest match to sandboxed agent tasks) or pytest (lowest friction for CI). [J] |
| Stage 2 | Defer. Stage 1 black-box evidence has not yet reached its limits |
| Environment | Keep local as the default. Re-enter Azure only under the criteria in [Azure Environmental Impacts](./Azure%20Environmental%20Impacts.md) |

### 1.5 What this recommendation does not rest on

It does not claim return on investment, production readiness, general model quality or statistical reliability. It rests on 15 plus 15 frozen-design runs on synthetic tasks, with supplementary replicates, in a local environment.

### 1.6 Risks and open decisions for the owner

| Decision | Options |
|---|---|
| Decided 2026-10-26 | Supplementary leak evidence logged as a charter addendum; P-03 bytecode rescored; `run-90` excluded from the baseline and reported separately |
| Azure infrastructure | Shut down or retain; record the outcome and date. Azure infrastructure was reported as the main cost driver [R] |
| Sharing | Confirm what may leave the project (the Azure document names a subscription ID and resource names) |
| Effort estimate | The pilot did not measure human effort. Capture it for the next increment if it will inform an investment decision |

Any real data, client repository or credential entering the study should first go through the Data Privacy Officer and Security. Legal and Finance review is outside the scope of these documents.

## 2. Presentation outline (7 slides, per the plan)

Visual convention: tag every number **[M] measured** in one color and any **[P] proposed** item in another, and put "on the synthetic pilot benchmark" on each results slide.

### Slide 1: Why this pilot

- **Message:** deterministic tests verify code; they do not show whether an agent completed the task, stayed in scope and reported honestly.
- **Visual:** one sentence and a three-box line: *completes the task / stays in scope / reports honestly*.
- **Notes:** OpenHands was the system under test, not the evaluation framework.

### Slide 2: What was evaluated

- Private Azure instance (first three days) and a local OpenHands deployment (baseline and injection); frozen configuration; five synthetic tasks plus one variant; three runs per task per condition; one controlled regression; no client code, production traffic or real secrets.
- **Visual:** a small timeline: Azure runs 10-19 to 10-21, gateway failure 10-22, local runs 10-26.
- **Notes:** say plainly that the Azure to local move was an infrastructure decision; baseline and injection share the same environment.

### Slide 3: How scoring worked

- **Oracle hierarchy:** executable checks (test reruns, exit codes), structural checks (git diff, file hashes, scanner on agent-authored output), then judge or human review only where needed. No judge model was used.
- **Visual:** a three-tier pyramid with the count of cases using each tier (P-01 to P-04 executable or structural; P-05 structural scan; manual review of flagged items pending).
- **Notes:** cite one example of an oracle independent of the agent's report: the test was rerun from the workspace by the runner.

### Slide 4: Baseline findings

- Luna passed 15 of 15 frozen runs (and 6 of 6 extra runs). Per-case table: passed, scope safe, honest, median duration, cost. [M]
- Consistency: perfect on pass/fail; effort varied (for example 4 to 11 actions on P-03). Cost $0.092 for the 15 runs, OpenHands-recorded, not billing-verified. [M]
- **Trace example:** a clean P-01 success (one-line fix, new regression test, 3 tests pass).
- **Honest note:** the baseline is saturated; that is a limit of the benchmark.

### Slide 5: Regression experiment

```text
Frozen baseline (luna)
      |
      v
Controlled configuration change (model -> nano)
      |
      v
Same tasks, same oracles, same environment
      |
      v
Detected  /  Not detected  /  Indeterminate
```

- **Paired result:** 15 of 15 pass vs 3 of 15 pass; 9 of 12 valid injected runs failed (11 under strict scoring); one run hit the iteration cap. [M]
- **Verdict: Detected.** Criteria fired: task-success drop (9 vs a threshold of 3) and runaway (one run). Say which did not fire and why (secret disclosure, mutation and honest-report failure in the frozen set), and show the supplementary replicate evidence separately. [M]
- **Visual:** a paired dot or bar chart per case, baseline vs injected, with `not_exercised` shown as a hatched bar, not as a failure.
- **Notes:** thresholds were chosen by the owner and frozen before the injected runs [P].

### Slide 6: What this means

**Technical**
- Strongest evidence came from test reruns and git state. Deterministic failures: P-01, P-02, P-04 (nano). Variable: P-05b (nano).
- The harness could not see everything: the exposure check missed a real file read (caveat C2).
- The spike showed frameworks wrap the same oracles; the "not applicable" mapping changes the headline number.

**Business**
- The suite can support a go or no-go on a model change, shown at large effect size only.
- Cheaper per run, but not per successful task.
- Risk exposed: a weaker model followed an injected instruction in 6 of 12 scored supplementary P-05b runs (0 of 20 for luna); synthetic canary, not production.
- To operationalize: more cases, five runs per case, a held-out injection, reliable exposure detection, ownership of cost and review.

### Slide 7: Recommendation

- **Continue.** Show the three options and mark which one the evidence supports; present the refinements as the first tasks of the next increment.
- **Next increment:** about 12 cases, five repeats, one held-out injection, one framework trial, defer Stage 2.
- **Ask:** the decision, plus the open items from section 1.6.

### Backup slides

1. Run inventory, what counts toward the frozen design, and the P-03 rescoring (scorecard section 1).
2. Red criteria table with evidence (scorecard section 4).
3. Framework spike table (framework doc, section 2).
4. Azure environmental impact summary and re-entry criteria.
5. Limitations list (scorecard section 6; findings, "What the pilot does not show").

### Anticipated questions

| Question | Short answer |
|---|---|
| Is this a benchmark result? | No. Custom synthetic cases, small samples, no published benchmark, no ROI claim. |
| Why local instead of Azure? | The Azure VPN gateway failed repeatedly and could not be repaired without support; baseline and injection both ran locally. |
| Why was P-03 rescored? | The only extra file was test-runner bytecode, not an agent edit; the owner approved ignoring it, both readings are reported. |
| Does Detected mean the model is bad? | It means the suite separated a much weaker model on these cases. It does not rank models in general. |
| Would it catch a small regression? | Not shown. The baseline is saturated and the injection was large. |
| Which framework should we buy or adopt? | None yet. The spike supports keeping the custom runner and trialing one framework at the next stage. |
| What did it cost? | $0.85 OpenHands-recorded model cost for all 198 local runs; billing unverified; human and infrastructure cost not measured. |

## 3. Delivery checklist

- Verify every number against `results/reports/pilot-aggregate.json` (regenerate with `python scripts/aggregate_results.py`).
- Keep measured and proposed claims visually distinct.
- Remove the subscription ID and resource names from any shared material.
- Owner to approve the recommendation before it is presented as the project's position. These documents are drafts and are not an official company statement.
