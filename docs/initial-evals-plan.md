# Evals Adoption Plan: OpenHands Agent Canvas (Brownfield Study)

**Date:** 2026-10-13
**Inputs:** [initial-evals-report.md](./initial-evals-report.md), [OpenHands-Guided-Sessions.md](../guided-sessions/OpenHands-Guided-Sessions.md)
**Status:** Draft for review. Framework characteristics in section 5 come from general knowledge and have not been checked against current docs. Phase 0 verifies them.
**Revision (2026-10-16):** The study no longer depends on building or modifying OpenHands. Stage 1 is fully black-box against the deployed instance and changes only what is reachable from outside (model, settings, released image version). Work that needs source changes and redeployment moves to an optional Stage 2, behind a decision gate (section 7.1). Sections affected: 1, 1.1, 4.2, 4.3, 4.6, 4.7, 6, 7, 8 and 9.

**Pilot execution note (2026-10-26):** a one-week concentrated pilot ([plan](./Concentrated%20Pilot/concentrated-plan.md), [charter](./Concentrated%20Pilot/experiment-charter-2026-10-19.md)) exercised a slice of this plan: five cases plus one variant, a custom runner, one Stage 1 injection (model substitution) and a bounded framework spike. It did not follow the eight-week schedule in section 7. Decisions that changed the plan as written: Azure was suspended after VPN gateway failures and the baseline and injection ran on a local OpenHands deployment (see [Azure Environmental Impacts](./Concentrated%20Pilot/Azure%20Environmental%20Impacts.md)); the baseline used 3 runs per case, not the k=5 proposed here; the framework spike covered Inspect AI, Promptfoo, pytest and DeepEval but not RAGAS. This document is otherwise unchanged and remains the full-study design.

## Executive summary

This plan runs three connected workstreams on one codebase.

| Workstream | Question | Output |
|---|---|---|
| **A. Process study** | What does it take to apply evals to a brownfield AI project, and what is repeatable? | A measured playbook with effort data and a friction log |
| **B. Before/after measurement** | Do evals produce measurable benefit for OpenHands? | A baseline and an after-state scorecard on pre-agreed metrics |
| **C. Framework bake-off** | How do RAGAS, Promptfoo and others compare on a real agentic system? | A weighted scorecard from implementing the same cases in each framework |

**Three design decisions shape the plan:**

1. **Evals do not improve a product by existing.** "Before" is "no evals", so a before/after comparison of product quality alone would be weak. The plan measures three separate things:
   - **Detection ability:** can we catch regressions we could not catch before?
   - **Decision quality:** does the team make better, faster changes?
   - **Product quality:** does it improve after iterating on eval findings?

   The strongest evidence is a **regression-injection experiment** (section 4.2), which tests detection directly.
2. **RAGAS is probably a poor fit, and the study should say so.** The report found no first-party RAG pipeline in this repo. RAGAS's core metrics (faithfulness, context precision/recall) assume retrieval. Include it, but score it on its agent metrics and on honest fit. A tool that doesn't fit is a legitimate finding for the brownfield question.
3. **Pick the system under test (SUT) deliberately.** Canvas is a frontend and launcher, and the Agent Server owns agent behavior. The report recommends not simulating that ownership. This plan treats the **SUT as the deployed Canvas plus Agent Server plus a recorded model config**, driven through the same API/UI paths users use. The deployed version is recorded and frozen for the study, not rebuilt from source. That still reaches agent quality.

4. **Private instance, no real traffic.** This is a private study against a private Azure instance deployed for the study. No real users exist, and no changes go back upstream.

5. **Two stages, with a gate.** Stage 1 does everything that needs no change to OpenHands code and reports on it. Stage 2 (source-level regression injection and code-level "post" changes) runs only if the Stage 1 report concludes it is needed (section 7.1). Every number comes from **controlled experiments on synthetic tasks** (locally and on the Azure instance), or from an **explicit model that extrapolates** those results to assumed usage. Reports must label each figure as *measured* (observed in a run) or *interpolated* (derived from stated assumptions). See sections 1 and 4.5.

**Proposed duration:** about 8 weeks, with an optional extension. See section 7.

---

## 1. Scope, assumptions and open decisions

**Facts (from the report):**
- Deterministic test maturity is strong: Vitest, MSW, Playwright, mock-LLM E2E.
- There is no golden dataset, judge rubric, benchmark runner or quality scorecard.
- The critic score is produced upstream and has no local calibration.
- Live E2E runs only on `main` or manual dispatch.

**Assumptions:**
- Read access to the repo and the ability to run a local Agent Server, plus an LLM API budget.
- All eval data is synthetic. No real user data is used.
- **The study runs against a private Azure instance of OpenHands. That instance has no real users and no user traffic, and nothing is contributed upstream.** The study team owns the instance, but not the upstream project. In Stage 1 the OpenHands code is not modified or rebuilt.
- The Azure instance is a **controlled test environment, not production**. It adds deployed-environment effects (latency, cold starts, auth, real cost) that a local stack cannot show. Open facts to record in Phase 0: single-user or shared, and which model endpoint provider is used.
- "Usage" means **simulated usage**: scripted tasks and synthetic workload models. Production behavior, user satisfaction and real incident rates are out of reach and are not claimed.
- The upstream PR, issue and CI history is the only source of "real" signal (for example, historical bugs). It is read-only and describes upstream's past, not this study's usage.

**Open decisions (these change the plan):**

| # | Decision | Recommendation |
|---|---|---|
| D1 | SUT boundary: Canvas only, or Canvas plus Agent Server? | Canvas plus Agent Server, as deployed. Without it there is almost nothing AI-specific to evaluate. **Limit:** agent behavior (prompts, tools, agent loop, critic) lives in `software-agent-sdk`, which is not part of this study. In Stage 1, "post" changes are limited to what is reachable from outside: model, settings, defaults and released image version (section 1.1). |
| D2 | Which model(s) and budget? | One pinned primary model, plus one cheaper model for the model-swap experiment. Set a hard cost cap per run. |
| D3 | Is the goal to contribute upstream or run a private study? | **Resolved: private study, no upstream contribution.** Eval artifacts and local changes stay in this copy. |
| D4 | Who are the SME labelers for judge calibration? | Name at least two people. Calibration is the main source of credibility for LLM-judge metrics. If none are available, use your own labels and limit judge-calibration claims. |
| D5 | Track upstream OpenHands changes during the study? | **Resolved: no.** Freeze the deployed version for the study and record its image tag and digest (section 4.7). Do not upgrade the instance between `pre` and `post` runs unless the upgrade is itself the experiment. |
| D6 | Fork `software-agent-sdk` so post changes can affect agent behavior? | **Deferred to Stage 2.** No in Stage 1. Revisit at the gate (section 7.1), and only if findings point to agent-side causes. |
| D7 | Build and modify OpenHands from source? | **Deferred to Stage 2.** Stage 1 needs no source. The local clone is kept as an optional asset for Stage 2 only, and it is not required. |

### 1.1 Where things live

**The evals live outside the OpenHands code and operate on running instances of it** (the local stack and the private Azure instance). They drive the system through the browser UI, REST and WebSocket, and read the event logs and workspace state.

```
Study repo (this project)                   Target (OpenHands, pinned)
─────────────────────────                   ──────────────────────────
dataset/    cases + fixtures    ──drives──▶ running instance (local or Azure)
frameworks/ eval implementations            via browser UI, REST, WebSocket
results/    scores + event logs ◀─reads───  event logs, workspace state
```

**Why outside:** evals ask whether the deployed agent does the task correctly and safely, which needs a running agent, a model and a workspace. Black-box evals run unchanged against `pre`, `post`, local and Azure builds, which keeps the pre/post comparison valid. They also keep the OpenHands copy clean, with no merge conflicts and nothing measured by code it depends on.

**What changes in Stage 1 (no OpenHands code is touched)**
- **"Post" changes** made in response to findings, limited to what is reachable from outside: model, settings and defaults through the UI or API, environment configuration, and switching to another released image version.
- **Regression injections of the same kind** (section 4.2, Stage 1 list).
- **The existing upstream tests are not run in Stage 1,** since there is no source tree. The detection comparison against the existing suite is therefore a Stage 2 item, or a desk comparison against upstream's published CI results.

**What changes in Stage 2 only (conditional, section 7.1)**
- **"Post" product changes** to the code, on a branch rebuilt into the image.
- **Source-level regression injections**, each a small patch applied to a copy of the source, built and deployed. The patches are stored as diffs in the study repo and are not committed to OpenHands.
- **The existing tests** run where they are, to build the detection comparison.

**Related repositories** (all under the `OpenHands` GitHub organization, per `AGENTS.md`; ownership of the organization is not verified here)

| Repo | Owns | How it enters the deployed image | In the study |
|---|---|---|---|
| `OpenHands/OpenHands` | Canvas UI, local-stack orchestration | This repo, built from source | The system under test |
| `OpenHands/software-agent-sdk` | Agent Server, agent loop, tools, API | Pinned base image (`agent-server`) | Pinned, not forked (D6) |
| `OpenHands/automation` | Scheduling and runs | PyPI package at a pinned version | Pinned |
| `OpenHands/extensions` | Public skills, plugins, templates | Fetched from the catalog at runtime | Drift source for plugin sessions. Record the date, or leave plugins out of the pre/post set. |

**Third-party dependencies:** the model provider (the largest drift source), npm and PyPI packages (pinned by lockfile and version), the Debian snapshot and container registry, and each eval framework (own license and data-handling terms). Check licenses before copying, hosting or sharing anything, and ask Legal if unsure.

**Folder layout** (created 2026-10-14; the study repo is `github.com/nates1973/eval-demo-openhands`, and `OpenHands/` is excluded from it by `.gitignore`)

```
Eval Demo - Open Hands/
├── OpenHands/            # OPTIONAL, Stage 2 only: local clone, untouched (own .git). Not needed for Stage 1.
├── docs/                 # report, plan, playbook (time log, friction log, final report)
├── dataset/              # cases.jsonl, schema.md, fixtures/
├── guided-sessions/      # OpenHands-Guided-Sessions.md, scripts/
├── workload/             # assumptions.csv, model/
├── injections/           # regression patches, held-out subset sealed
├── frameworks/           # implementations only: custom/, promptfoo/, ragas/, deepeval/, inspect-ai/, scorecard.md
├── results/              # runs/<date>_<env>_<pre|post>_<framework>_<run-id>/, baselines/, reports/
└── scripts/              # scrub logs, aggregate, bootstrap CIs
```

Results are organized by run, not by framework, so pre/post pairing and cross-framework comparison stay in one place. Raw logs stay out of git. Only scrubbed logs and aggregates are committed.

---

## 2. Workstream A: Evaluate the brownfield process

The meta-question is what applying evals to an existing project costs and what it yields. Instrument the work itself.

### 2.1 Process stages to time and document

| Stage | Activity | Artifact |
|---|---|---|
| 0. Discovery | The assessment already done (the report) | Report, with hours recorded |
| 1. Scoping | Choose SUT, risk-rank features, agree metrics | This plan |
| 2. Dataset bootstrapping | Mine existing tests, specs, bug history, and write golden cases | Versioned JSONL dataset |
| 3. Harness build | Runner, fixtures, pinning, result store | Benchmark runner |
| 4. Baseline | Run N times and publish variance | Baseline scorecard |
| 5. Iterate | Fix, tune or triage based on findings | Change log tied to eval deltas |
| 6. Operationalize (design and dry run only) | Draft CI wiring, ownership and maintenance cadence. Exercise them locally, in a throwaway CI sandbox and against the private Azure instance. Nothing is rolled out to a live team. | CI job definitions, a runbook and a maintenance-effort estimate (interpolated) |

### 2.2 Process metrics (measured, not estimated)

| Metric | How measured |
|---|---|
| Effort per stage (person-hours) | Time log kept from day one |
| Time to first meaningful eval result | Days from kickoff to first scored run |
| **Reuse ratio:** fraction of golden cases seeded from existing assets (tests, specs, feature-map recipes, bug reports) | Tag each case's `source` field |
| Discovery yield: number of previously unknown defects or ambiguities found per stage | Findings log |
| Friction log | Dated entries: blocker, workaround, cost, whether it generalizes |
| Dataset authoring rate (cases/hour) and review rejection rate | Case metadata |
| Harness flake rate (indeterminate or infra-failed runs / total) | Runner logs |
| Marginal cost per eval run (tokens, dollars, wall-clock) | Runner logs |

### 2.3 Generalization check

At the end, tag each friction entry as **repo-specific**, **brownfield-general** or **agentic-general**. The brownfield-general and agentic-general entries become the playbook. Because this is one repo, state that limit explicitly. A single case study supports hypotheses, not general claims. If time allows, a second, smaller repo would test the playbook.

---

## 3. Evaluation target model

The existing test suite stays in place. Evals add a layer that answers a different question:

| Layer | Question | Examples | Owner |
|---|---|---|---|
| Deterministic tests (existing) | Does the code behave as specified? | Vitest, MSW, Playwright | Canvas |
| **Agent behavior evals (new)** | Does the agent complete tasks correctly and safely? | Seeded-repo tasks, tool-trace and forbidden-action checks | Shared |
| **Judge-based evals (new, small)** | Is the response honest and helpful where no oracle exists? | Rubric judge, calibrated against humans | Shared |
| **Critic calibration (new, optional)** | Does the critic score predict real success? | Critic score vs. oracle outcome | Agent Server owner |

**Oracle hierarchy.** Prefer the strongest available oracle for each case:
1. Executable (tests or build pass, exit codes, worktree diff)
2. Structural (tool-trace assertions, schema checks)
3. LLM judge with a rubric
4. Human review

Use a lower level only when a higher one cannot express the requirement.

---

## 4. Workstream B: Before/after measurement

### 4.1 Metric set

Pre-register the metrics and thresholds **before** the baseline run, so results cannot be cherry-picked.

All metrics below are computed from scripted runs against the pinned local stack or the private Azure instance (section 4.6). Tier 1 results describe performance **on the benchmark**, not in production. Anything that would need real users or a real team is either replaced with a simulated equivalent (marked below) or dropped.

**Tier 1: Agent quality (primary outcome, on synthetic tasks)**

| Metric | Definition | Oracle |
|---|---|---|
| Task success rate | Fraction of golden tasks where the executable oracle passes | Tests and build |
| Scope-control rate | Fraction with no unrelated file changes | Diff vs. allowed paths |
| Forbidden-action rate | Fraction with any violation (mutation in a "do not modify" task, unapproved execution in plan mode, secret exposure) | Tool trace and worktree hash |
| Tool-use accuracy | Correct tool, arguments and call count | Tool trace |
| Honest-report rate | Final summary matches actual outcome (for example, it does not claim passing tests when they fail) | Judge plus executable check |
| Pass^k consistency | Fraction of cases passing in all k runs (k=3 or 5) | Repeated runs |

**Tier 2: Detection and safety-net value (the "benefit of evals")**

| Metric | Definition |
|---|---|
| **Injected-regression detection rate** | Fraction of seeded regressions caught, comparing existing suite only vs. existing suite plus evals (section 4.2) |
| Historical-regression recall | Fraction of past PR/bug regressions that the eval suite would have flagged when replayed |
| Time to detect | Wall-clock from applying an injected change to the first red signal, per mechanism. Measured in the injection experiment, with no real developers involved. |
| Detection overlap | Regressions caught only by evals, only by the existing suite, or by both |
| False-positive rate | Alarms on known-good changes, measured via an A/A comparison |

**Tier 3: Process and delivery**

| Metric | Definition |
|---|---|
| Simulated change decisions | Run scripted change scenarios (model swap, prompt edit, config change). Record whether the eval evidence leads to the correct accept/reject call, compared with the existing suite alone. This replaces "change confidence", which needs a real team. |
| ~~Review cost~~ | Dropped. There are no real PRs or reviewers. Use the review-load proxy instead: the number of eval failures a reviewer would need to triage per injected change. |
| Eval cost per run | Measured dollars and minutes per run. It must stay below a pre-set budget or the suite would not be run. Projected monthly cost is **interpolated** (section 4.5). |
| Coverage of the risk map | High-risk feature families (P1/P2 rows of the roadmap) with at least N golden cases |

**Tier 4: Judge reliability** (only if judges are used)

| Metric | Definition |
|---|---|
| Judge-human agreement | Cohen's kappa or Spearman correlation vs. SME labels on a held-out set |
| Judge self-consistency | Score variance across repeated judging runs |
| Judge sensitivity | Does the judge catch known-bad outputs (planted failures)? |

### 4.2 Regression-injection experiment (core of the evidence)

Evals earn their value by catching problems the current process misses. Test that directly. The experiment runs in two stages, split by whether the regression can be applied without changing OpenHands code.

**Stage 1: externally reachable regressions (no code changes)**

Candidate classes. Phase 0 verifies which are actually reachable on the deployed instance. Drop or move to Stage 2 any that are not.
- Model swap to a weaker or cheaper model
- Default-setting change through the UI or API (for example, the empty-model-setting case in GQ-08)
- Tool-approval or confirmation mode changed
- Agent Server or Canvas version change, by redeploying a different released image (upgrade or downgrade)
- Configuration or environment changes (for example, an upload size limit, if it is configurable without a rebuild)

**Stage 2: source-level regressions (needs code changes and redeployment, conditional)**
- Wrong-workspace routing
- Secret leaked into events
- Stale state after backend switch
- Truncated or altered diff reporting
- Any change to the tool-approval gate logic itself
- Upload size limit changed, if it is not configurable

**Procedure (both stages)**
1. Build the library of 15–25 plausible regressions. Tag each `stage: 1` or `stage: 2`. Stage 1 may produce fewer than 15, and the report states the actual number.
2. Apply each, one at a time, to the instance or a fixture, and revert before the next.
3. Record which mechanisms flag it. In Stage 1 the mechanisms are the new evals and any signal visible from outside (errors, UI state, `/server_info`). Existing PR CI, nightly E2E and mock-LLM E2E need the source tree, so they join the matrix in Stage 2.
4. Report the detection matrix per stage. The marginal detection rate versus the existing suite is a Stage 2 result. Stage 1 reports the evals' own detection rate and which regression classes are out of reach.

**Blinding:** the person who writes the injected regressions should not be the person who tunes the evals. Otherwise the evals will be implicitly fit to the injections. Keep roughly a third of injections held out until after the suite is final.

**Reuse (Stage 2):** the repo has optional Stryker mutation testing. Mutation-score results are a useful comparison for what the deterministic suite already catches, but they cover code-level mutants, not agent-behavior regressions. Present them as a complement.

### 4.3 Experimental design

| Concern | Approach |
|---|---|
| **Baseline definition** | "Before" means (a) the existing CI and E2E signals plus (b) the unchanged system scored on the new dataset. Record both. Without (b) there is no quality baseline. In Stage 1, (a) is a desk review of upstream's published CI configuration and results, since the tests are not run locally. |
| **Nondeterminism** | Run each case k times (start k=5 for the baseline). Report means with bootstrap confidence intervals. Do not claim an improvement smaller than the run-to-run noise. |
| **Pinning** | Record and freeze the deployed image tag and digest, the Agent Server and Canvas versions reported by `/server_info`, model ID and version, temperature, seed (where supported), fixture repo commits, and the dataset version (section 4.7). |
| **After-state meaning** | "After" has two parts: (1) the suite is built and runs against the private instance, and (2) the system has been modified using findings. In Stage 1, modification means external changes only (model, settings, released version). Code changes are Stage 2 (private edits, redeployed only to the private instance, never released). Report detection benefits from (1) and quality improvement from (2) separately. Evals do not change the system by themselves, so a pre/post comparison measures the effect of the changes made in response to findings, not of the evals. Neither is a production outcome. |
| **Attribution** | Log each product change with the eval finding that motivated it. Don't credit evals for improvements that came from a model upgrade. Use a model-held-constant comparison where possible. |
| **Dataset hygiene** | Dev/test split. Tune only against dev. Report on a held-out test split. Keep failure history when cases are retired. |
| **Honesty about limits** | A single system, one team, one 8-week window, and no real users. Avoid ROI dollar claims. Report measured effects and costs, and label every extrapolation. |
| **Measured vs. interpolated** | Every figure in a report carries a tag: **M** (observed in a run) or **I** (derived from the workload model). Tag **I** figures need their assumptions and an uncertainty range alongside them. |

### 4.4 Dataset build plan

Start from the report's catalog (GQ-01 to GQ-12, GD-001 to GD-012) and grow to the 30–50 case minimum it recommends.

| Source | Expected contribution | Notes |
|---|---|---|
| Report golden questions and dataset rows | 12 | Already specified |
| Existing mock-LLM and live E2E scenarios, converted | 8–12 | High reuse. Tag `source: e2e`. |
| Feature-map recipes (F01–F27) | 6–10 | Manual recipes made executable |
| Past bugs and regression tests | 6–10 | Mine commit and issue history. Minimize into fixtures. |
| Adversarial and red-team cases | 6–8 | Secret exfiltration, malicious extension manifest, prompt injection via repo contents |
| No-op and refusal cases ("do not modify", "report only") | 4–6 | Cheap and high-signal |

**Schema (JSONL),** extending the report's fields:
`id, feature, risk, prompt, fixture, expected_state, required_tool_trace, forbidden_actions, oracle_type, assertions, source, split (dev|test), review_status, added_in_version, notes`

**Fixtures:** small synthetic repos with a known defect, a failing-test repo, a mock MCP server (`qa_echo`), and a sample extension manifest. Version them with the dataset.

### 4.5 Simulated usage and interpolation

With no real traffic, the study builds an explicit **workload model** and extrapolates from measured results. The model is a labeled assumption set, not data.

**What is simulated**

| Element | Approach |
|---|---|
| Task mix | Weight golden-case families by assumed usage frequency and risk (from the feature map). Publish the weights. |
| Change stream | Assume a rate of agent-adjacent changes per week (for example, model bumps, prompt edits, config changes) and a regression probability per change class. Use ranges, not point values. |
| User behavior | Scripted multi-turn and queued-follow-up sessions, including the guided sessions in section 4.6. No claim that these resemble real users. Guided-session results are measured evidence about system behavior. They cannot validate the usage frequencies they encode. |

**What is interpolated (tag I)**

| Output | Derivation |
|---|---|
| Expected regressions caught per month | Injection detection rate (M) × assumed regression rate (assumption) |
| Expected escaped regressions | Same model, using the existing-suite-only detection rate |
| Projected monthly eval cost | Measured cost per run (M) × assumed runs per month (PR subset plus nightly) |
| Maintenance effort | Measured authoring and triage hours (M) scaled by assumed dataset growth |

**Controls**
- Keep an **assumptions register** (value, range, rationale, owner). Report every I figure as a range.
- Run a **sensitivity analysis**: vary each assumption and show which ones drive the conclusion. If a conclusion flips within a plausible range, say so.
- Anchor regression-class frequencies to upstream's public bug and PR history where possible. State that this describes upstream's past, not this study's usage.
- Report measured detection rates as the primary evidence. Interpolated figures are illustrative scenarios.

#### 4.5.1 Grounding sources

No production data is available, so assumptions are grounded in public or self-generated evidence. Use these sources in order of preference.

| Source | Informs | Evidence grade | Limits |
|---|---|---|---|
| Upstream public GitHub history: releases, merged PRs, issues, bug labels, reverts, hotfixes | Change rate per week, regression frequency per change class | **G1** (public-history-derived) | Describes upstream's development, not usage. Bug labels are inconsistent, so sample and hand-classify. Record the sample size. |
| Published agent trajectories and benchmark results (for example SWE-bench-style runs) | Task shapes, steps and tool calls per task, failure modes, cost per session | **G2** (benchmark-derived) | Benchmark tasks are not a real user mix. Verify availability and license before use. |
| Public surveys and usage reports on AI coding tools | Coarse priors on task categories | **G3** (external, non-specific) | Not specific to this product. Use only to set ranges. |
| Own dogfooding: real, non-client tasks run on the local copy or the Azure instance over about two weeks, logged | Prompt style, follow-up patterns, abandonment | **G4** (self-observed) | Small n, one user type. Informs scripted sessions, not frequencies. |
| Expert judgment | Anything else | **G5** (assumed) | No evidence. Use the widest range and flag it in reports. |

**Rules**
- Every assumption cites at least one source and its grade. Combine sources only by recording each one.
- Record a G5 assumption's range as wide enough that the conclusion is tested against it in the sensitivity analysis.
- Do not collect colleagues' or client-project usage. Dogfooding covers only your own sessions on non-client work. If wider usage collection is ever proposed, stop and consult the Data Privacy Officer first.
- Check the license and terms of any public dataset before copying content into the eval dataset. Prefer to record aggregate statistics, not raw content.
- Never record secrets, client names or personal data in dogfooding or guided-session logs. Scrub API keys, Azure endpoints and tokens before logs are stored or quoted.

#### 4.5.2 Assumptions register template

Keep this as `workload/assumptions.csv` (or a table in the final report appendix). One row per assumption. Version it with the dataset.

| Field | Description |
|---|---|
| `id` | `A-001`, `A-002`, and so on |
| `name` | Short label, for example "weekly agent-adjacent change count" |
| `category` | `change_stream`, `task_mix`, `regression_rate`, `run_frequency`, `session_shape` or `cost` |
| `unit` | For example `changes/week`, `probability`, `runs/month` |
| `low` / `base` / `high` | Range used in the model. `base` is the central scenario. |
| `source` | Where the value came from (URL, query, file or "judgment") |
| `grade` | G1–G5 (section 4.5.1) |
| `sample_size` | Number of observations, if any |
| `rationale` | Why this range, in one or two sentences |
| `sensitivity_rank` | Filled after the sensitivity analysis. 1 = most influential. |
| `owner` | Person who maintains the entry |
| `date` | Date set or last reviewed |
| `status` | `proposed`, `frozen` or `revised` |

**Example rows (illustrative values to replace, not data)**

| id | name | category | unit | low | base | high | source | grade | rationale |
|---|---|---|---|---|---|---|---|---|---|
| A-001 | Agent-adjacent changes per week | change_stream | changes/week | TBD | TBD | TBD | Upstream merged-PR sample, last 6 months | G1 | Count PRs touching agent or config paths in a hand-classified sample |
| A-002 | Regression probability, model or default-setting change | regression_rate | probability | TBD | TBD | TBD | Upstream reverts and bug-labeled follow-ups | G1 | Share of such changes followed by a fix or revert |
| A-003 | Share of sessions that are no-mutation tasks | task_mix | fraction | TBD | TBD | TBD | Own dogfooding log | G4 | Small sample, so keep the range wide |
| A-004 | Eval runs per month | run_frequency | runs/month | TBD | TBD | TBD | Judgment | G5 | Depends on PR volume (A-001) plus one nightly run |

**Freeze rule.** Freeze `low`, `base` and `high` before the injection experiment, as with the metric thresholds in section 4.1. After that, change them only as a logged revision with a reason, and report both versions.

### 4.6 Guided sessions on the private Azure instance

Guided sessions are scripted, repeatable sessions run against the private Azure instance. Each has a known standard to score against. They are the **deployed-environment tier** of the golden dataset, not a second dataset.

**Design**
- **Scripts:** Each fixes the prompt (or turn sequence), fixture repo commit, model config, expected end state and oracle checks. A metadata header records the case ID, the assumption IDs it embodies (section 4.5.2), the assertions and the oracle type.
- **Shared schema:** Use the section 4.4 JSONL schema with `tier: deployed`. Keep the dev/test split so reported sessions are not the ones used for tuning.
- **Driver:** Runs each script through the same API/WebSocket path users use, captures the event log, runs the oracle checks and writes to the same result store as local runs. Tag each result with environment, `pre`/`post` and run number.
- **Sessions:** The twelve session scripts (GS-01 to GS-12) are specified in [OpenHands-Guided-Sessions.md](../guided-sessions/OpenHands-Guided-Sessions.md). They are a draft that has not yet been dry-run. Share the schema with the dataset, or the two sets will drift apart.

**Pre/post comparison**
- **Pinning:** Pin model ID, image tag and instance configuration. Record Azure region and any provider-side model version info.
- **Noise floor:** Run an A/A pair (two `pre` runs) first. Do not claim effects smaller than that noise.
- **Repeats and pairing:** Run k repeats per script and pair results by script. Report bootstrap confidence intervals.
- **Confounders:** Silent model updates by the provider, Azure load variation and version drift. Re-run a `pre` sample at the end to check for drift.
- **What "post" means:** The system after iterating on eval findings (section 4.3). It is not "evals installed", since that changes nothing by itself. In Stage 1, "post" is limited to external changes (model, settings, released version), so the pre/post comparison may show little or no product-quality change. Report that honestly. To test the eval gate itself, apply injected regressions to the instance (section 4.2) and record whether the evals flag them.

**What this evidence is and is not**
- Measured (M): system behavior under controlled tasks, plus deployed-environment effects such as latency, cold starts and cost.
- Not evidence for: usage frequencies, user behavior or production incident rates.

**Controls**
- Synthetic fixtures only, with no client code or data.
- Hard spend cap on the model endpoint.
- Scrub logs (section 4.5.1) before storing them or quoting them in reports.

### 4.7 Frozen deployment and version record

**Policy (D5, revised):** the study does not build OpenHands. It evaluates the instance that is deployed, records exactly what that is, and freezes it. Upstream changes several times a day, and an upgrade between `pre` and `post` would mix upstream's changes with yours, so no difference could be attributed to your changes. Upgrade the instance only when the upgrade is itself an experiment (section 4.2, Stage 1).

**Values to record at the start of Phase 0 and in every run's metadata**

| Item | Source |
|---|---|
| Image reference and **digest** | Container configuration (`config/openhands-dev-container.yaml`) and the registry. A tag alone is not enough, since tags can move. |
| Agent Server, Canvas and Automation versions | `/server_info` and the container logs |
| Upstream commit, if the image exposes it | `org.opencontainers.image.revision` label or the `AGENT_CANVAS_BUILD_GIT_SHA` variable. Record "not available" if absent. |
| Model ID, provider and version | Instance settings, plus provider-side version info where available |
| Instance configuration | Settings export or the container environment, with secrets removed |
| Azure region, container size, single-user or shared | Azure portal or deployment files |
| Telemetry state | Whether upstream analytics is reachable from the instance. Check the container's outbound traffic or configuration. If it cannot be disabled by configuration, record it as a known limitation, and do not rebuild just to remove it in Stage 1. |

**Phase 0 findings (2026-10-16, from live Azure queries and `/server_info`; details in `config/azure.local.yaml`, which is git-ignored)**
- **Deployment:** an Azure Container Instance in resource group `brownfield-evals-experiment`, westus. Running, 0 restarts, started 2026-10-16 18:27 UTC. Earlier config files described a different, older deployment and are no longer valid.
- **Image:** `ghcr.io/openhands/agent-canvas:latest`, an upstream prebuilt image on a floating tag. Open item: pin by digest (step 1 below).
- **Measured versions (re-checked after the redeploy):** Agent Server, SDK, tools and workspace 1.54.0 (`refs/tags/v1.54.0`). Canvas and Automation versions are not reported by `/server_info` and remain unverified. The Agent Server runs inside the same container, so the SUT is one deployed unit (D1).
- **Local clone is not the deployed code:** the `OpenHands/` clone is at commit `71427af5…`, which was chosen before the deployment was rebuilt. It has not been matched to the image. Confirm the match before using the clone in Stage 2.
- **Network posture (updated 2026-10-16 after redeploy):** the container now has only a private IP (`10.0.2.4`) in subnet `ContainerNet` (`10.0.2.0/24`), which is delegated to Azure Container Instances and has a `Microsoft.Storage` service endpoint. `/server_info` answers over the VPN and the old public IP no longer responds. Access is still plain HTTP, so `LOCAL_BACKEND_API_KEY` is unencrypted inside the VNet and VPN path. The storage account `openhandsstorage` is now restricted: default action Deny, a single VNet rule allowing `ContainerNet`, no IP rules, and the `AzureServices` bypass (output supplied by the study owner, since the query is blocked for the assistant). One caveat: with `bypass: AzureServices`, trusted Azure services can still reach the account, and the account key remains the credential for the file shares.
- **Model:** nothing in the container configuration names a model or endpoint, and the spend cap is not enforced by the container. D2 remains open.

**Deploy and operate (Stage 1)**
1. **Identify the current deployment** from the table above and record it as the `pre` baseline. If the digest cannot be recorded, redeploy once using a digest-pinned reference.
2. **Persistence and reset:** confirm persistent volumes for `/home/openhands/.openhands` and `/projects`, and write a reset procedure between runs.
3. **Secrets and access:** secret key, session API key and model credentials held as Azure secrets. HTTPS, with inbound access restricted to your IP or VPN, because the instance runs agent-executed code.
4. **Spend cap** on the model endpoint.
5. **Version-change experiments** (Stage 1 injection class): deploy a different released image by digest, run the suite, and restore the baseline digest. Record both digests.
6. **Record** the digest and the environment fields in every run's metadata.

**Stage 2 only: build from source.** If the gate (section 7.1) approves code-level work:
- Pin an upstream commit in a copy of the source (the local `OpenHands/` clone is already at `71427af5b426b3f1270db86341dffe30a947d53c`, dated 2026-10-14; confirm it matches the deployed image first).
- Rebuild `pre` from that commit and redeploy, so `pre` and `post` use the same pipeline and build differences cannot affect results. Do not compare a modified build against an older prebuilt image.
- Build with `node scripts/docker-build.mjs --tag <name> -- --build-arg OPENHANDS_BUILD_GIT_SHA=<sha>` for amd64. Use immutable tags such as `pre-<sha7>` and `post-<nn>`, never `latest`.
- Make post changes and injections in a copy of the tree, never in `OpenHands/` itself. Apply the same telemetry change to both builds so it is not a confounder.

**Optional later extension:** run the suite against successive upstream releases. Each break is a real regression the suite did or did not catch. It is separate evidence from the pre/post pairs. It needs only released images, so it can run in Stage 1 if time allows.

---

## 5. Workstream C: Framework comparison

### 5.1 Candidates

| Framework | Why include it | Expected fit for this SUT (hypothesis, to verify) |
|---|---|---|
| **Promptfoo** | Popular, config-driven, CLI and CI friendly, supports red teaming and custom providers | Good for config-matrix and red-team cases. Agent multi-step tracing is the question. |
| **RAGAS** | Named in the request, a widely cited metric library | Likely weak: built for RAG. Evaluate its agent metrics (tool-call accuracy, goal accuracy). |
| **DeepEval** | Pytest-style, broad metric catalog including agentic metrics | Plausible. Fits the existing Python script tests. |
| **Inspect AI** | Built for agent and sandboxed evals, with strong task and scorer abstractions | Plausible best fit for sandboxed seeded-repo tasks. |
| **Custom harness (pytest plus Playwright plus scripts)** | The honest baseline: what it costs to skip a framework | Strong for executable oracles. Lacks reporting and judge tooling. |
| *Optional (platforms):* LangSmith, Braintrust, Arize Phoenix, TruLens | Hosted or observability-first tools | Include only as a lightweight desk review, not a full implementation. They add data-governance questions, so involve Compliance and the Data Privacy Officer before any real data leaves the environment. |

Phase 0 refreshes this list. The space changes quickly and versions matter, so record the exact version tested.

### 5.2 Method: same cases, every framework

Desk comparison is unreliable for this question. Instead:

1. Choose **8–10 representative cases** that stress different capabilities:
   - Executable-oracle coding task (GD-001)
   - No-mutation honesty task (GD-002)
   - Tool-trace assertion (GD-004)
   - Approval gate / trust boundary (GD-005, GD-009)
   - Config matrix (GD-007)
   - Secret non-disclosure red-team (GD-012)
   - A pure judge-rubric case
   - A multi-turn or queued-follow-up case (GD-011)
2. Implement each in every shortlisted framework, **timeboxed** (for example, 2 days per framework), using the same SUT and pinned model.
3. Record outcomes on the scorecard below, with evidence (code size, setup time, errors hit).
4. Run each implementation twice to compare result stability across frameworks (same case, same SUT).

### 5.3 Scorecard criteria

Score 1–5 with evidence. Weights are proposals, to be agreed before scoring.

| Criterion | Weight | What to look for |
|---|---|---|
| **Agentic fit:** multi-step, tool-trace, and sandbox/workspace-state assertions | 20% | Can it assert on tool calls, call counts, files and diffs, not only text? |
| **Oracle flexibility:** executable, structural and judge in one run | 15% | Custom scorers, shell or test execution, non-LLM assertions |
| **Brownfield integration:** drives an existing HTTP/WebSocket Agent Server, reuses existing fixtures and tests, works beside TypeScript tooling | 15% | Provider and adapter model, language fit (repo is TypeScript, scripts are Python) |
| **Judge quality tooling:** rubric support, judge model choice, calibration and agreement support | 10% | Does it support or at least not hinder human calibration? |
| **Reproducibility and statistics:** repeat runs, variance, pinning, caching | 10% | Native support for k runs and confidence intervals |
| **CI and workflow:** exit codes, thresholds, artifacts, cost controls | 10% | PR gating and nightly separation |
| **Reporting and diffing:** compare runs, regressions, trace viewing | 5% | Usable without paid add-ons? |
| **Security and data governance:** self-hostable, no mandatory data egress, secrets handling | 5% | Required for confidential contexts |
| **Developer experience:** time to first result, docs, debuggability | 5% | Measured setup time |
| **Maintenance and community:** release cadence, license, pricing model, lock-in | 5% | Exact license and cost terms to be checked |
| **Red-team capability** | Reported but not weighted | Relevant to P1 secrets and extension-trust area |

Report the weighted total **and** the per-criterion scores, since weighting reflects this project's priorities. Also state a recommendation per use case (for example, "best for sandboxed agent tasks", "best for config matrices").

---

## 6. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Nondeterminism produces noisy conclusions | k repeats, confidence intervals, minimum detectable effect stated up front |
| Budget overrun from model-backed runs | Hard per-run cost cap, cached deterministic cases, small PR subset vs. larger nightly set |
| Evals tuned to the injected regressions | Blinded authoring and a held-out third |
| Judge bias or drift | SME-labeled calibration set, judge-human agreement metric, never use a judge as the sole gate for safety or data-integrity cases |
| Scope creep into building the agent evals the Agent Server team should own | Keep to the SUT boundary (D1). Hand over critic calibration as a recommendation. |
| Credentials or real data enter datasets | Synthetic secrets and fixtures only. If real support data is ever proposed, stop and consult the Data Privacy Officer before use. |
| Framework conclusions go stale | Record versions and dates. Treat the scorecard as a snapshot. |
| Single-case-study overreach | State limits. Frame playbook items as hypotheses. |
| Simulated workload does not resemble real usage | Publish the workload model and assumptions register. Use ranges and sensitivity analysis. Never present results as production performance. |
| Cloud drift or noise confounds pre/post on Azure | Pin versions, run the A/A noise floor, pair by script, re-run a `pre` sample at the end (section 4.6). |
| Secrets or endpoints leak through session logs | Scrub before storage, synthetic fixtures only, spend cap on the model endpoint. |
| Interpolated figures mistaken for measurements | M/I tagging on every reported number. Keep I figures out of headline claims. |
| Deployed version drifts or is upgraded mid-study | Freeze the instance, record the image digest in every run, and re-run a `pre` sample at the end (sections 4.6, 4.7). |
| Build differences confound pre/post (Stage 2) | Rebuild `pre` from the pinned commit through the same pipeline as `post`. Immutable tags and recorded digests (section 4.7). |
| Study traffic reaches upstream analytics | Check and record the telemetry state (section 4.7). In Stage 2, blank the key in both builds. |
| Stage 1 detection matrix is narrower than the full design | Tag each injection by stage, report the number actually run, and list the regression classes that were out of reach. Decide at the gate (section 7.1). |
| Stage 1 shows little pre/post product change | Expected, since only external changes are possible. Report it as a finding, and let the gate decide whether code-level changes are warranted. |
| Agent-behavior findings cannot be fixed without code changes | State the limit (D1). Take it to the gate (D6, D7). Otherwise report such findings as recommendations. |

---

## 7. Phased timeline (about 8 weeks for Stage 1, plus an optional Stage 2)

Stage 1 changes no OpenHands code. Stage 2 is conditional and has its own gate.

| Phase | Weeks | Activities | Exit criteria |
|---|---|---|---|
| **0. Setup and verification** | 1 | Settle D1, D2, D4 (D3 and D5 are done, D6 and D7 are deferred). Record and freeze the deployed version (section 4.7). Verify which injection classes are externally reachable. Verify framework facts against current docs. Confirm the Azure instance facts (single-user or shared, model endpoint provider, spend cap). Start time and friction logs. Pre-register metrics and thresholds. | Decisions recorded, deployment recorded, metrics frozen |
| **1. Dataset v0 and custom harness** | 2–3 | Build fixtures. Write 30+ cases. Implement the custom harness (baseline tool). | Dataset v0 reviewed. First scored run. |
| **2. Baseline** | 3–4 | k-run baseline scorecard and A/A noise floor. Desk review of upstream's published CI signals. Build the injection library, tagged by stage. Draft the workload model and assumptions register. Collect SME calibration labels. | Baseline report with confidence intervals |
| **3. Framework bake-off** | 4–6 | Implement the 8–10 cases in each framework. Complete the scorecard. | Scorecard with evidence |
| **4. Stage 1 detection experiment and iteration** | 6–7 | Run the Stage 1 injection matrix. Iterate on findings using external changes only. Re-run on the held-out test split. Run the interpolation model and sensitivity analysis. | Stage 1 detection matrix, after-state scorecard and tagged projections |
| **5. Stage 1 synthesis and gate** | 8 | Playbook, framework recommendation, process-metric analysis, limitations, and the gate recommendation (section 7.1). | Stage 1 final report |
| **6. Stage 2 (conditional)** | TBD after the gate | Build `pre` from a pinned commit. Run the source-level injection matrix and the existing-suite comparison. Make code-level post changes and re-measure. | Stage 2 addendum to the report |

Phases 2 and 3 can overlap if two people are available.

### 7.1 Stage 2 decision gate

At the end of Phase 5, the Stage 1 report includes a recommendation, and you decide whether to continue.

**Evidence that favors stopping after Stage 1**
- The Stage 1 detection matrix covers the regression classes that matter most for the P1/P2 risk map.
- The evals detected the externally reachable regressions at an acceptable rate, with usable confidence intervals.
- The playbook and framework recommendation are supported by the work done.
- The remaining questions (marginal value against the existing suite, code-level fixes) are not needed for the study's stated goals.

**Evidence that favors continuing to Stage 2**
- Important regression classes (secrets in events, workspace routing, approval-gate logic) were out of reach and are central to the study's claims.
- Findings point to causes in Canvas or Agent Server code that cannot be tested or fixed externally.
- The comparison with the existing suite is needed for the benefit claim.

**Gate output:** a short decision record in `docs/` with the recommendation, the evidence, the expected Stage 2 effort and cost, and the decision. If Stage 2 proceeds, settle D6 and D7 at that point.

---

## 8. Deliverables

1. `dataset/` with versioned JSONL, fixtures and a schema document
2. `frameworks/` with the custom baseline runner and the per-framework implementations
3. Baseline and after-state scorecards (Tier 1–4 metrics, with confidence intervals)
4. Regression-injection detection matrix (Stage 1, with a Stage 2 addendum if the gate approves it)
5. Workload model and assumptions register (section 4.5.2), with grounding-source evidence and sensitivity analysis
5a. Guided-session scripts, driver and pre/post results from the Azure instance (section 4.6)
5b. Deploy, reset and version-change runbook for the Azure instance, with the frozen-deployment record (section 4.7)
6. Framework comparison scorecard and use-case recommendations
7. Brownfield evals playbook: stages, effort data, friction log, generalization tags
8. Final report: executive summary first, then method, results and limitations, with every figure tagged measured or interpolated
9. Stage 2 gate decision record (section 7.1)

---

## 9. Immediate next steps

1. Decide D1, D2 and D4. D3 and D5 are resolved, and D6 and D7 are deferred to the gate. If SME labelers are not available, D4 needs a fallback, for example your own labels with a documented limit on judge-calibration claims.
2. Record and freeze the deployed version (section 4.7): image digest, `/server_info` versions, model configuration, instance settings.
3. Check which injection classes are reachable from outside, and tag the injection library by stage.
4. Choose and pin the model configuration and set the cost cap.
5. Freeze the metric list and thresholds (section 4.1).
6. Ask me to draft the dataset schema and the first 12 JSONL cases from the report, or the custom harness skeleton, as the first build task.

*Review note: this is an internal planning draft. If any part is shared outside the team, for example in a client deliverable, have it reviewed first. Confirm the framework licensing and data-handling terms with Legal and Compliance, and have the Data Privacy Officer review any plan that uses real user data.*
