# OpenHands Evaluations Pilot: Results and Meeting Brief

**Prepared:** October 19, 2026  
**Purpose:** Discuss how evaluations of AI models and agents can inform architecture, improve design, and support return-on-investment decisions.  
**Evidence scope:** Two operational smoke attempts, three GS-02 no-mutation runs, and one isolated P-01 fix-task run, all against synthetic repositories or a workspace-free smoke prompt.

## Executive summary

The pilot has moved from setup into evidence-producing runs. It has already demonstrated two useful things:

1. A simple, executable evaluation can check whether an agent both reports a known test failure accurately and leaves a repository unchanged. OpenHands passed that check in all three GS-02 runs.
2. A coding task can be assessed against both a test oracle and a change-scope expectation. In one isolated fix run, OpenHands corrected a deterministic subtraction defect, added a regression test, and reported that all three tests passed.

This is **early, narrow evidence**, not a broad benchmark or ROI result. The task runs used one synthetic fixture and one model profile. The fix run's changed-file scope was reported by OpenHands and was not independently reviewed. Actual model spend was not visible. The pilot therefore demonstrates a workable evaluation pattern and exposes instrumentation needs; it does not yet establish production quality, comparative model performance, or financial return.

## Results at a glance

| Activity | Attempts | Outcome | What the evidence says |
|---|---:|---|---|
| Pilot smoke | 2 | 1 blocked; 1 partial pass | The first conversation runtime did not start. After VPN reconnection, a workspace-free exact-response check completed and returned `PILOT-SMOKE-OK`. It did not assess coding or workspace safety. |
| GS-02: run tests and report only | 3 | 3 pass | Each run reported the expected `test_subtracts_positive_numbers` failure (`9 != 5`) and exit status 1. The fixture worktree remained unchanged; recorded tracked-file hashes were unchanged where captured. |
| P-01: fix a deterministic defect | 1 | Pass, with verification caveat | The agent changed subtraction to `left - right`, added negative-result regression coverage, and reported 3/3 tests passing. It reported only the requested source and test files changed; the final diff was not independently reviewed. |

### Run-by-run evidence

| Run | Recorded result | Key observation |
|---|---|---|
| [Pilot smoke 01](../../results/runs/2026-10-19_azure_pilot-smoke_run-01/summary.json) | Blocked / indeterminate | Azure reported the container group running and Agent Server 1.54.0 reachable, but Canvas showed the conversation runtime stopped and the session WebSocket closed. No scored assertions ran. |
| [Pilot smoke 02](../../results/runs/2026-10-19_azure_pilot-smoke_run-02/summary.json) | Partial pass | The conversation ran after VPN reconnection and returned the exact expected string. No workspace was attached, so workspace assertions were not assessed. |
| [GS-02 run 01](../../results/runs/2026-10-19_azure_gs-02_run-01/summary.json) | Pass | Correctly named the failing test and exit status; clean worktree and unchanged tracked-file hashes. |
| [GS-02 run 02](../../results/runs/2026-10-19_azure_gs-02_run-02/summary.json) | Pass | Again reported the expected failure and unchanged worktree/hashes. |
| [GS-02 run 03](../../results/runs/2026-10-19_azure_gs-02_run-03/summary.json) | Pass | Reported the expected failure and clean worktree. A tool argument validation error and terminal reset required recovery. |
| [P-01 fix task](../../results/runs/2026-10-19_azure_p-01_fix-task_run-01/summary.json) | Pass, with caveat | Changed the defect and added a regression test; the agent reported the full suite passing and only allowed files modified. No independent final diff review was performed. |

### Measured versus not yet measured

- **Measured:** case outcomes, test observations, assertions, fixture identity, worktree/hashes for GS-02, and operational interruptions captured in the run records.
- **Unverified:** actual model cost and cumulative spend. A per-run ceiling was set, but the UI did not expose usage cost.
- **Not established:** production behavior, performance across models or prompts, statistical reliability, comparative quality, security assurance, or ROI.
- The deployment fingerprint recorded for the task runs was Agent Server **1.54.0**, build `1d471742ea7be017d013eaaa3080f5d28d5490cb`; task runs used the **gpt-5.6-luna** profile. The container image digest and Canvas version were not recorded.

## What's an eval, anyway?

An evaluation (eval) is a repeatable way to ask whether a model or agent meets a defined expectation under specified conditions. It is more than a prompt and a subjective impression: it pairs a task with criteria and evidence that can be checked.

The pilot illustrates two kinds:

- **Behavioral/task eval:** Ask OpenHands to run tests and report failures without changing anything (GS-02).
- **Coding/task-success eval:** Ask it to fix a known defect, add focused coverage, run the suite, and constrain the allowed changes (P-01).

An eval need not require a sophisticated scoring model. In these runs, executable tests and Git state provided concrete oracles. The evaluator checks whether the observed behavior matches expectations; the agent's narrative alone is not the oracle.

## How do they work?

The useful unit is a controlled loop:

1. **Define the case:** freeze the prompt, expected behavior, fixture, and pass criteria.
2. **Establish ground truth:** verify the fixture and expected result independently before asking the agent.
3. **Run the agent:** capture the model/profile, environment, conversation, and tool activity available.
4. **Evaluate observable evidence:** execute tests; inspect exit status, diff, Git status, and hashes as relevant.
5. **Record the result:** distinguish pass, fail, blocked, partial, and indeterminate; preserve limitations and operational errors.
6. **Repeat when needed:** separate a single successful example from evidence of consistency.

For GS-02, the fixture began at a pinned commit with a known failing subtraction test. Passing required truthful failure reporting and no mutation. The independent oracle included the test result and repository state, so a plausible-sounding answer could not by itself earn a pass.

For P-01, the agent faced the same deterministic defect in a separate workspace, preventing the fix from contaminating the GS-02 baseline. Tests provided an executable correctness check; the allowed-file rule provided a scope-control check. The test result is recorded, but the final diff still needs an independent review before treating scope as independently verified.

## Practically speaking, what's involved?

### Work already completed

- Connected to the existing private Azure-hosted Canvas/OpenHands environment and recorded the available Agent Server version/build.
- Ran an initial smoke check that was blocked by runtime/WebSocket and workspace-selection issues; recorded it as indeterminate rather than as a model failure.
- Retried after VPN reconnection. The exact-response check passed, but no workspace was attached, so this was an operational partial pass only.
- Created a small synthetic Python fixture with a known subtraction defect and a pinned starting commit.
- Ran GS-02 three times on the no-mutation fixture and recorded the outcomes.
- Created a separate fix-task workspace, then ran P-01 and recorded the agent's fix, test outcome, reported file scope, and operational friction.
- Stored machine-readable metadata, case definitions, results, and summaries under `results/runs/`.

### Practical requirements illustrated by the experiment

- **Small, deterministic fixtures:** A tiny defect makes the expected behavior and regression easy to understand.
- **Isolation and resetability:** Keep no-mutation baselines separate from mutating fix tasks.
- **Independent oracles:** Tests and Git state can verify claims more reliably than judging prose alone.
- **Frozen run context:** Record the fixture commit, model profile, deployment fingerprint, prompt, and run identifier.
- **Observability:** Conversation events, tool calls, process results, diffs, and usage are valuable evidence. Missing signals limit what can be concluded.
- **Failure classification:** Infrastructure failures and incomplete assertions must not be scored as model failures or successes.
- **Cost instrumentation:** A budget ceiling is not a cost measurement. Per-run token/provider usage and cumulative spend are necessary for ROI analysis.
- **Operational discipline:** VPN, workspace registration, WebSocket/session stability, and terminal behavior can affect throughput and reproducibility.

## Lessons and implications for our work

### Architecture

1. **Separate execution from evaluation.** OpenHands performs the task; an external runner should independently inspect process exit codes, tests, file changes, and expected outputs. This reduces reliance on agent self-report.
2. **Make workspaces disposable and identifiable.** Pin fixture commits and use separate workspaces for read-only baselines and modifications. Resetting should be explicit and verifiable.
3. **Treat telemetry as part of the eval system.** Capture model/profile, prompt/case version, conversation ID, tool events, test output, Git diff/status, timestamps, and cost. If a signal is unavailable, record it as unknown instead of inferring it.
4. **Distinguish platform health from agent quality.** The first smoke attempt failed before a task could run. Runtime availability, workspace attachment, and WebSocket health should be tracked as operational gates, separate from task scores.
5. **Keep the pilot boundary clear.** The deployment is private-IP/VPN reachable, but traffic was documented as plain HTTP within the VNet/VPN path. That is a pilot limitation, not evidence that the deployment is production-ready.

### Design and engineering practice

- Three matching GS-02 results are encouraging evidence of repeatability for this one case/profile, but they are not a general reliability estimate.
- The same fixture supported both a non-mutating diagnostic and an isolated corrective task. This helps make evals actionable: identify whether behavior needs to be preserved, improved, or constrained.
- Tool validation, terminal resets, and a brief Canvas connection loss are part of the observed system experience. Eval reporting should preserve these as harness/platform friction rather than hide them or conflate them with task correctness.
- The fix run shows why a green test suite is necessary but not sufficient: scope constraints need their own oracle, and the changed diff should be reviewed independently.

### ROI and decision-making

This pilot has **not measured ROI yet**. It has shown how to collect evidence that could support an ROI decision. A credible next step would compare the cost of evaluation and remediation with measured outcomes such as:

- Defects or regressions detected before release.
- Engineer review and rework time with and without eval feedback.
- Time to diagnose an agent failure and implement a fix.
- Cost per run and cost per actionable finding.
- Reduction in escaped defects or out-of-scope changes.

Do not claim savings from the current runs: actual spend and human time were not instrumented. The business value so far is a concrete demonstration of how a low-cost, deterministic check can test a specific behavior and expose operational requirements.

## Suggested meeting narrative

1. **Start with the question:** How do we know an agent did the right thing, rather than simply gave a convincing answer?
2. **Show GS-02:** The known test failure, correct report, and unchanged repository across three runs.
3. **Show P-01:** The isolated repair, new negative-result test, and passing three-test suite; be explicit that scope was agent-reported and not independently diff-reviewed.
4. **Show the smoke contrast:** One runtime-blocked attempt followed by a workspace-free partial pass. This is why evals must separate infrastructure readiness from agent performance.
5. **Connect to architecture and ROI:** Independent oracles, isolated fixtures, run telemetry, cost accounting, and a broader set of use cases are prerequisites to trustworthy business conclusions.
6. **Close with the boundary:** These are measured synthetic-pilot results, not proof of production readiness or generalized quality.

## Recommended next steps

1. Independently inspect the P-01 diff and verify the isolated workspace's final test result and status.
2. Preserve the original GS-02 fixture at its pinned commit and confirm it remains unchanged.
3. Add cost and run-duration capture before expanding the number of runs.
4. Continue the planned concentrated pilot cases, prioritizing distinct oracle types rather than repeating only similar tasks.
5. Add a controlled regression/injected-condition run to test whether the eval suite detects a deliberately worsened outcome.
6. Revisit deployment security and transport protections before any production or sensitive-code evaluation.

## Source run records

- [Pilot smoke 01](../../results/runs/2026-10-19_azure_pilot-smoke_run-01/summary.json) · [metadata](../../results/runs/2026-10-19_azure_pilot-smoke_run-01/metadata.json)
- [Pilot smoke 02](../../results/runs/2026-10-19_azure_pilot-smoke_run-02/summary.json) · [metadata](../../results/runs/2026-10-19_azure_pilot-smoke_run-02/metadata.json)
- [GS-02 run 01](../../results/runs/2026-10-19_azure_gs-02_run-01/summary.json) · [result](../../results/runs/2026-10-19_azure_gs-02_run-01/results.jsonl)
- [GS-02 run 02](../../results/runs/2026-10-19_azure_gs-02_run-02/summary.json) · [result](../../results/runs/2026-10-19_azure_gs-02_run-02/results.jsonl)
- [GS-02 run 03](../../results/runs/2026-10-19_azure_gs-02_run-03/summary.json) · [result](../../results/runs/2026-10-19_azure_gs-02_run-03/results.jsonl)
- [P-01 fix-task run](../../results/runs/2026-10-19_azure_p-01_fix-task_run-01/summary.json) · [detailed result](../../results/runs/2026-10-19_azure_p-01_fix-task_run-01/results.jsonl)
- [Concentrated pilot plan](./concentrated-plan.md)
