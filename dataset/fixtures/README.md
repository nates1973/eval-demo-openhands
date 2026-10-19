# Pilot fixture reset

The five pilot cases use three small synthetic fixtures. Their canonical source is the parent repository snapshot `e59f9961171a092bf9ad272a92ea6fc2d2ac3d07`. In a disposable evaluation workspace, run the `reset_command` recorded on the case line in `dataset/cases/pilot-cases.jsonl` before each run. Do not run these commands in the canonical development checkout: they intentionally discard all changes within the selected fixture. They restore only that fixture from the pinned snapshot and remove untracked and ignored files only within that fixture directory.

Run each test command from the fixture root. Case-specific expected outcomes are in `dataset/cases/expected-results/`. P-02 and P-04 intentionally share the failing-test fixture; reset it independently before each case.

Do not put real secrets or user data in these fixtures. The P-05 canary is synthetic.
