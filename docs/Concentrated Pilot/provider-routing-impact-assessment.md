# Provider Routing Issue: Impact on the Concentrated Pilot Plan

**Assessment date:** 2026-10-19 (Tuesday work started early)
**Plan assessed:** [concentrated-plan.md](./concentrated-plan.md)
**Status:** Routing is controlled as of 2026-10-20 (see the update below). P-01 has a completed baseline run on `gpt-5.6-luna`. The sections after the update describe the 2026-10-19 state.

## Update 2026-10-20/21: routing controlled; P-01 baseline obtained on luna

The sections below describe the state on 2026-10-19 and are kept as written. Current status:

- **Egress is now restricted and observable.** Azure Firewall `experiment-firewall` (policy `experiment-firewall-policy`, rule `Only-Azure-AI-Models`) allows only `*.openai.azure.com` on 80/443 from `<private-ip>/24`. A route table sends `0.0.0.0/0` from ContainerNet to the firewall. Application-rule logs go to Log Analytics workspace `firewall-logs` (table `AzureDiagnostics`, columns `Fqdn_s`, `Action_s`; about 5-7 minutes of delay). Tests showed `api.openai.com` denied and the Azure host allowed.
- **Smoke calls** on `gpt-5.6-luna` and `gpt-5.6-terra` returned `PILOT-SMOKE-OK`, and the firewall showed only Azure Allow entries. The terra conversation's recorded model was not confirmed to have changed (see open items).
- **Root cause of attempts 1-3 is still unconfirmed and was not reproduced.** The firewall now prevents any non-Azure call from succeeding, and a preflight snapshot records the effective profile, model and endpoint host. The earlier hypothesis of a dangling `default` profile was wrong: on a local backend the seeded `default` agent profile launches from global settings on the active LLM profile.
- **P-01 on luna** ran through Azure with 0 firewall denials. Run-01 (`max_iterations` 6) stopped with `MaxIterationsReached` before any edit, which is a case-design finding (planning and inspection alone use about 5-6 steps), not a model failure. Run-02 (`max_iterations` 25) completed: correct one-line fix, regression test added, only the two allowed files changed, 3 tests reported passing, cost about $0.014 as recorded by OpenHands. See [run-01](../../results/runs/2026-10-20_azure_p-01_v11_run-01/summary.json) and [run-02](../../results/runs/2026-10-20_azure_p-01_v11_run-02/summary.json).
- **Workspace finding.** `/projects` on the container is ephemeral disk and not a file share. The persistent mount is `/project` (share `openhands-project`). P-01 now runs in `/project/qa-repo-p01-v11`, its own git repo (commit `ae0da31`), so git status/diff scoring works. Git needs `safe.directory` for that path because of share ownership; the setting is probably lost on container restart.
- **Max iterations is not editable in this Canvas build's UI.** It is set via `PATCH /api/settings` on the Agent Server with `{"conversation_settings_diff": {"max_iterations": N}}` (Swagger at `/docs`, header `X-Session-API-Key`). It is global and currently **25**; the default is 500.
- **Canvas "add a backend" prompt** is the per-browser backend registry in `localStorage`, not a server-state problem.

- **Terra confirmed (2026-10-21).** After switching the active profile to `gpt-5.6-terra` (read back from `/api/settings`), a P-01 run recorded `openai/gpt-5.6-terra` in both the conversation and its usage metrics, so a profile switch does change the model used. Run-03 passed with the same scope and fix; cost was about $0.146 against luna's $0.014 (about 10x), with similar token counts. See [run-03](../../results/runs/2026-10-21_azure_p-01_v11_run-03/summary.json). Treat the cost gap as a candidate signal for the Friday substitution, not a quality finding at n=1.

**Still open**
- Independent rerun of the P-01 tests (runs 02 and 03 test results are agent-reported); Azure billing not verified.
- Replace the stale YAML configs; add a mandatory preflight to the runner design; classify routing and auth failures as infrastructure failures.
- Reset `max_iterations` after the pilot, and decide the cap for P-02 to P-05.

## 1. Issue summary

Three attempts to run P-01 through the Azure OpenHands deployment ended in provider authentication errors before the agent used any tools or ran any tests.

| Attempt | Evidence | Result |
|---|---|---|
| 1 ([run 01](../../results/runs/2026-10-19_azure_p-01_tuesday-preflight_run-01/metadata.json)) | Request sent to `https://api.openai.com/v1/responses` | HTTP 401 `invalid_api_key` |
| 2 ([run 02](../../results/runs/2026-10-19_azure_p-01_tuesday-preflight_run-02/metadata.json)) | Request again sent to `api.openai.com`, although the **Evals Experiment Foundry** connection has an Azure base URL; the conversation's effective LLM settings had no `base_url` | HTTP 401 `invalid_api_key` |
| 3 ([run 03](../../results/runs/2026-10-19_azure_p-01_tuesday-preflight_run-03/metadata.json)) | Conversation saved the Azure base URL and the same connection ID; actual outgoing host **not confirmed** | `LLMAuthenticationError` |

OpenHands recorded 0 tokens and $0 model cost for all three. Azure billing is not independently verifiable, so $0 is the provider-reported figure only.

### Known and unknown

**Known**
- Fixtures, case definitions, expected results, and local oracles were prepared and verified independently of OpenHands.
- The Agent Server was reachable over the VPN (version 1.54.0).
- Earlier conversations that used the same connection ID completed work and recorded costs (GS-02 runs, P-01 fix-task run).
- In attempt 2, the Azure endpoint was not part of the effective conversation LLM settings, and the request went to OpenAI.

**Not yet established**
- Where attempt 3's request actually went, and which service returned the authentication error.
- Whether the stored credential is valid for the Azure resource and the `gpt-5.6-luna` deployment.
- Why earlier conversations worked and these did not (difference in profile/connection resolution, credential state, or request construction).
- Whether the problem affects only conversations created through the API route used here, or also Canvas UI conversations.

The root cause is therefore **unconfirmed**. This document assesses impact under both plausible scenarios:

- **Scenario A (configuration propagation):** the Azure endpoint/credential is not applied to conversations created the way the runs were created. This is likely correctable in how conversations are created.
- **Scenario B (credential or deployment problem):** the stored credential or model deployment is invalid or mismatched. This requires a repair by the key owner.

## 2. Overall impact

| Question | Assessment |
|---|---|
| Is the experiment invalid? | **No.** Failures occurred before any agent behavior; no scored data is affected. |
| Is the SUT (OpenHands behavior) shown to be defective? | **No.** This is an environment/configuration blocker, not a finding about agent quality. |
| Is it limited to P-01? | **No.** P-01 through P-05 all require a working model call. |
| Does it block the pilot? | **Yes, for every model-backed step** (Tuesday execution onward) until a smoke call succeeds. |
| Does it threaten the Friday injection? | **Potentially, significantly.** See Friday below. |
| Is there schedule slack? | Tuesday work started on Monday, October 19, so there is some buffer, but the plan has no spare day. |

Impact levels used below: **None**, **Low**, **Medium**, **High (blocked)**.

## 3. Step-by-step impact

### Monday, October 19: Freeze the experiment — **Low** (completed; one caveat)

| Plan item | Impact |
|---|---|
| Deployment fingerprint | Image digest, Agent Server/SDK versions, region, and container configuration were recorded. The frozen record already lists *"Scored-run model provider/model ID and generation parameters"* and *"Actual model cost or enforceable spend cap"* as **not verified** ([freeze record](../../results/verification/azure-freeze-2026-10-19.json)). This issue makes that gap material. |
| Operational controls | VPN-only access and synthetic fixtures are unaffected. **Spend control remains manual only**: no Azure budget is configured and Azure Cost Management queries failed, so the $15 limit is not technically enforced. |
| Metrics frozen | Unaffected. |
| Charter | Should add a known limitation: provider routing and credential state were not part of the frozen fingerprint. |

**Action:** amend the fingerprint to record the effective provider connection, endpoint host, model deployment, and how conversations select them.

### Tuesday, October 20: Build five eval cases — **Low for design, High for deployed verification**

| Plan item | Impact |
|---|---|
| Five fixtures, versioned case definitions, reset commands | **None.** Prepared and pinned to commit `e59f9961171a092bf9ad272a92ea6fc2d2ac3d07`. |
| Independent oracle verification | **None.** Done locally, outside OpenHands, as required by the plan. P-01/P-02/P-04 baselines fail and P-03 baseline fails as expected; repaired copies pass; P-05 passes ([oracle validation](../../dataset/cases/oracle-validation-2026-10-19.json)). |
| Case readiness | Case definitions still show readiness flags such as `local_oracle_verified_openhands_run_pending`. **No case has been verified end to end in OpenHands under the v1.1 fixture.** |
| P-01 Azure run | **Blocked.** Three attempts failed. A prior P-01 run used a different fixture commit and cannot replace this. |

**Action:** treat the end-to-end OpenHands pass for each case as *not complete*, even though the fixtures and oracles are ready.

### Wednesday, October 21: Thinnest runner — **High (blocked)**

| Plan item | Impact |
|---|---|
| Fixture reset, oracle execution, aggregation, reporting | Can be built and tested without a model. Reset commands were already validated in an isolated worktree. |
| Submit prompt, capture events and final response | **Cannot be validated** without a working model call. |
| Critical milestone: one complete scored run (prompt → OpenHands → capture → oracle → record) | **At risk.** This is the plan's critical milestone and it depends on the provider. |
| Result record fields (`model`, `image_digest`, etc.) | Need an additional field for the **effective endpoint and connection** so routing errors are detectable by the harness. |

**Actions**
- Add a mandatory **preflight smoke call** to the runner. It should confirm the effective model, base URL host, and authentication before any case is submitted.
- Classify provider authentication/routing failures as `infrastructure_failure` or `indeterminate`, never as a case failure. The plan already requires separating SUT failures from harness or infrastructure failures.
- The plan's fallback (a repeatable manual driver) does not avoid this issue, because the model call is still required.

### Thursday, October 22: Baseline and noise floor — **High (blocked), with a validity risk**

| Plan item | Impact |
|---|---|
| 15 baseline executions (5 cases × 3 runs) | **Blocked** until routing is fixed. |
| Same image, model, configuration, fixtures | **Validity risk.** If some conversations route through one endpoint and others through another, the baseline mixes conditions. Every run must record and verify the effective endpoint. |
| Cost per execution | Provider-reported cost is zero for failed calls and cannot be independently confirmed. Costs for successful runs must be read from OpenHands usage and labeled as unverified unless Azure billing becomes available. |
| Harness or infrastructure failures | Failed attempts must be **counted and reported separately** from case outcomes, not folded into pass rates. |
| Budget | The $15 ceiling is manual. Run repetition should be gated by per-run usage checks. |

**Action:** do not begin repeated baseline runs until a smoke test and one full-case run succeed through the verified route.

### Friday, October 23: Inject one regression (model substitution) — **High; the most sensitive step**

This is where the issue matters most, because the preferred injection is a model/profile change, which is exactly the area where routing is currently unreliable.

| Plan item | Impact |
|---|---|
| Model substitution as the regression | Substituting a model changes which profile and connection resolve for a conversation. Both `gpt-5.6-luna` and `gpt-5.6-terra` profiles reference the same connection, so the substitution would also depend on correct endpoint propagation. |
| Controlled comparison validity | If a substituted model silently routes to a different endpoint (for example, OpenAI directly instead of Azure), the comparison is no longer a model-only change. **Detection could be confounded or invalid.** |
| Pre-defined "red" thresholds | Unaffected, but a failed provider call must not be counted as a red signal (for example, "task success drops"). Authentication failures are **indeterminate**, not detection. |
| Restoration | Restoration verification must include the **effective endpoint**, not only image digest and model ID. |
| Alternative injections (confirmation mode, default model setting, environment configuration, image pinned by digest) | Less dependent on provider routing, but they still need a working baseline model call. An "empty or incorrect default model setting" injection would be hard to separate from this existing defect and should be avoided until routing is understood. |

**Actions**
- Verify routing for **both** the baseline and the substitute model before freezing the injection design.
- Record the effective endpoint host for every injected-condition run.
- Treat any provider authentication/routing failure as *Indeterminate because of harness or infrastructure failure*, one of the plan's three legitimate outcomes.
- Prefer a non-routing injection if routing cannot be made reliable in time.

### Weekend: Analyze — **Medium**

| Plan item | Impact |
|---|---|
| Separate SUT failures from harness/infrastructure failures | This issue is a clear infrastructure failure example and must be reported separately. |
| Friction log | Valuable entry: provider connection labeled Azure but a conversation was sent to OpenAI; successful and failed conversations resolve configuration differently. |
| Verify every number against result files | Failed-attempt records (three blocked runs, zero usage) must appear in totals as blocked attempts, not as case results. |
| Scrub logs | Provider error logs and request URLs must be scrubbed; never record credentials. |

### Monday, October 26: Present — **Medium**

| Slide | Impact |
|---|---|
| 1–3 (why, what was evaluated, scoring) | Unaffected. Slide 2 should state the model provider, endpoint, and routing verification accurately. |
| 4 Baseline findings | Depends entirely on getting successful baseline data. Cost figures must be labeled unverified if Azure billing is not confirmed. |
| 5 Regression experiment | Outcome could be "Indeterminate" if routing cannot be stabilized for the injection. |
| 6 Interpretation | A routing or credential defect is a **real finding for a brownfield EDD study**: a deployment can look correctly configured (profile reports an active connection, key set) while requests go elsewhere. Present it as an environment/configuration discovery, not as an OpenHands agent-quality result. Do not claim a product bug unless confirmed. |
| 7 Recommendation | Likely recommendation: *Refine* (add a mandatory provider preflight and effective-configuration verification before every eval run). |

## 4. Success criteria check (from the plan)

| Criterion | Status |
|---|---|
| 1. Evaluate a running agent repeatably from outside | **At risk** until a model call works through a verified route. |
| 2. At least one executable/structural oracle result | Oracles verified locally; **no OpenHands-based result yet** for the v1.1 cases. |
| 3. Consistency or nondeterminism across repeats | Not started. |
| 4. Controlled change assessed by the suite | At risk (Friday depends on routing). |
| 5. Cost, friction, limitations recorded | **On track.** This issue is itself recorded friction. |

## 5. Recommended path

1. **Keep model-backed runs paused.**
2. **Diagnose without spending tokens:** compare a known-good conversation with the failed ones (profile, connection ID, effective `base_url`, auth type), and obtain the sanitized server log for attempt 3's outgoing host and response. Do not print environment variables or keys.
3. **Decide scenario A or B.** If A, create conversations in the form that carries the Azure endpoint. If B, the key owner repairs the credential or deployment; no key should be sent in chat.
4. **Run one minimal smoke call** through the verified route, then one P-01 run, and verify tests and changed paths.
5. **Add the preflight and effective-endpoint recording** to the Wednesday runner design, and classify routing/auth failures as infrastructure failures.
6. **Resume cases sequentially** with usage checks between runs and the $15 limit enforced manually. Stop and alert on any authentication failure, block, or dropped connection.
7. **Re-evaluate the Friday injection** after routing is proven for both models.

## 6. Decision points for the owner

| Decision | Options |
|---|---|
| Who verifies the credential/deployment? | Key owner confirms the credential is valid for `brownfield-evals-experi-resource` and the model deployment. |
| Whether to enable cost visibility | Configure an Azure budget/alert and confirm cost data access, or accept manually tracked, unverified costs. |
| Friday injection choice | Model substitution (preferred, depends on routing) or a non-routing alternative. |
| Schedule | Confirm whether Tuesday–Wednesday absorb this delay or the plan needs a contingency day. |

## 7. Related records

- [Run 01](../../results/runs/2026-10-19_azure_p-01_tuesday-preflight_run-01/metadata.json), [run 02](../../results/runs/2026-10-19_azure_p-01_tuesday-preflight_run-02/metadata.json), [run 03](../../results/runs/2026-10-19_azure_p-01_tuesday-preflight_run-03/metadata.json)
- [Budget ledger](../../results/verification/azure-tuesday-budget-2026-10-20.json)
- [Deployment freeze record](../../results/verification/azure-freeze-2026-10-19.json)
- [Oracle validation](../../dataset/cases/oracle-validation-2026-10-19.json)
- [Provider configuration notes](./provider%20configuration%20issue.txt) (general external guidance; not confirmed as the cause here)
