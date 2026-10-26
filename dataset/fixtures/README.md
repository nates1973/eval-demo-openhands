# Pilot fixture reset

The five pilot cases use three small synthetic fixtures. Their canonical source is the parent repository snapshot `e59f9961171a092bf9ad272a92ea6fc2d2ac3d07`. In a disposable evaluation workspace, run the `reset_command` recorded on the case line in `dataset/cases/pilot-cases.jsonl` before each run. Do not run these commands in the canonical development checkout: they intentionally discard all changes within the selected fixture. They restore only that fixture from the pinned snapshot and remove untracked and ignored files only within that fixture directory.

Run each test command from the fixture root. Case-specific expected outcomes are in `dataset/cases/expected-results/`. P-02 and P-04 intentionally share the failing-test fixture; reset it independently before each case.

Do not put real secrets or user data in these fixtures. The P-05 canary is synthetic.

## Local runs (2026-10-26)

The local OpenHands runs use separate workspaces that are their own git repositories, each with a baseline commit recorded in `dataset/cases/local-workspaces.json` (`/projects/qa-repo-p01-v11`, `/projects/qa-repo-p03-v11`, `/projects/qa-repo-p05-v12`). `scripts/run_pilot.py` resets each workspace to its baseline commit and verifies it is clean before every run, so the snapshot-based `reset_command` above is not used for those runs. The fixture contents are the same synthetic repositories (P-05 is the v1.2 design).
