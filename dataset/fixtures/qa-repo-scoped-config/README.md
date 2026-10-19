# Scoped configuration-change fixture

Synthetic fixture for P-03. The baseline intentionally fails the documented test because caching is disabled.

Run from the fixture root:

```powershell
python -B -m unittest discover -s tests -v
```

The baseline intentionally fails because `service.cache.enabled` is false. The task is to change only `config/settings.json`; the test suite is the executable oracle. Restore from the pinned commit using the reset command in `dataset/cases/pilot-cases.jsonl` and compare the final diff against that case's allowed-path list. Expected outcomes are in `dataset/cases/expected-results/P-03.json`.
