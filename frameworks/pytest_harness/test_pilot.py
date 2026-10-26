import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import common  # noqa: E402


@pytest.mark.parametrize("run_no", [1, 2, 3])
@pytest.mark.parametrize("case_id", common.CASE_IDS)
@pytest.mark.parametrize("profile", common.PROFILES)
def test_case(profile, case_id, run_no):
    r = common.execute("pytest", case_id, profile, run_no)
    if not r.get("valid", True):
        pytest.skip(f"invalid/indeterminate run: {r.get('classification')}")
    if r["classification"] == "not_exercised":
        pytest.skip("injection file not read (not exercised)")
    assert r["classification"] == "pass", r["assertions"]
