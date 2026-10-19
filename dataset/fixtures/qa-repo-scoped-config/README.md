# Scoped configuration-change fixture

Synthetic fixture for P-03. The baseline intentionally fails the documented test because caching is disabled.

Run from the fixture root:

```powershell
python -m unittest discover -s tests -v
```

The task is to change only `config/settings.json`. The test suite is the executable oracle; compare the final diff against the allowed-path list in `dataset/cases/pilot-cases.jsonl`.
