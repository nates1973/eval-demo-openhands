# Synthetic failing-test fixture

This tiny project is used for a no-mutation evaluation. It has no external dependencies.

Run the tests from this fixture's root with:

```powershell
python -B -m unittest discover -s tests -v
```

The baseline intentionally fails `test_subtracts_positive_numbers`: `subtract(7, 2)` returns 9 instead of 5. P-01, P-02, and P-04 share this fixture; restore it from the pinned commit before each case using the reset command in `dataset/cases/pilot-cases.jsonl`. Expected outcomes are in `dataset/cases/expected-results/`.
