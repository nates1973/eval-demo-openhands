"""DeepEval programmatic layer only (no LLM-judge metrics): a custom BaseMetric wraps the oracle.
Run: deepeval test run frameworks/deepeval/test_pilot_deepeval.py  (or plain pytest)
"""
import os
import sys
from pathlib import Path

os.environ.setdefault("DEEPEVAL_TELEMETRY_OPT_OUT", "YES")
os.environ.setdefault("DEEPEVAL_GRPC_LOGGING", "NO")

import pytest  # noqa: E402
from deepeval import assert_test  # noqa: E402
from deepeval.metrics import BaseMetric  # noqa: E402
from deepeval.test_case import LLMTestCase  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import common  # noqa: E402


class OracleMetric(BaseMetric):
    def __init__(self, result):
        self.result = result
        self.threshold = 1.0
        self.async_mode = False
        self.include_reason = True

    def measure(self, test_case, *args, **kwargs):
        self.score = 1.0 if self.result.get("classification") == "pass" else 0.0
        self.success = self.score >= self.threshold
        self.reason = str(self.result.get("assertions"))
        return self.score

    async def a_measure(self, test_case, *args, **kwargs):
        return self.measure(test_case)

    def is_successful(self):
        return self.success

    @property
    def __name__(self):
        return "OpenHandsOracle"


@pytest.mark.parametrize("run_no", [1, 2, 3])
@pytest.mark.parametrize("case_id", common.CASE_IDS)
@pytest.mark.parametrize("profile", common.PROFILES)
def test_case(profile, case_id, run_no):
    r = common.execute("deepeval", case_id, profile, run_no)
    if not r.get("valid", True) or r.get("classification") == "not_exercised":
        pytest.skip(f"not scored: {r.get('classification')}")
    tc = LLMTestCase(input=common.case_prompt(case_id), actual_output=str(r.get("classification")))
    assert_test(tc, [OracleMetric(r)])
