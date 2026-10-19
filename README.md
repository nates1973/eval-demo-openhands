# eval-demo-openhands
Demonstrate brownfield application of AI evals

A private practice study of applying evals to a brownfield AI project. The study team's own evals run, black-box, against a privately deployed instance of [OpenHands](https://github.com/OpenHands/OpenHands) (Agent Canvas). Nothing here is contributed upstream, and the OpenHands code is not part of this repository.

Start with [docs/initial-evals-plan.md](docs/initial-evals-plan.md).

| Folder | Contents |
|---|---|
| `docs/` | Assessment report, plan, and the playbook (time log, friction log, final report) |
| `dataset/` | Golden cases (JSONL), schema, fixtures |
| `guided-sessions/` | Scripted sessions for the Azure instance ([spec](guided-sessions/OpenHands-Guided-Sessions.md)) |
| `workload/` | Assumptions register and the interpolation model |
| `injections/` | Regression patches for the detection experiment |
| `frameworks/` | Eval framework implementations (custom, Promptfoo, RAGAS, DeepEval, Inspect AI) |
| `results/` | Run data, baselines and reports. Raw logs are git-ignored. |
| `scripts/` | Shared tooling (log scrubbing, aggregation, statistics) |
| `OpenHands/` | Optional local clone of the upstream code, used only if the plan's Stage 2 proceeds. Untouched and git-ignored, because it is a separate repo. |

**Rules**
- Synthetic fixtures only. No client code, client names or personal data.
- Never commit credentials or unscrubbed logs.
- Do not check out, pull or edit anything in `OpenHands/`. The deployed version is recorded as described in section 4.7 of the plan.
