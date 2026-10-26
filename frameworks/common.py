"""Shared adapter core: every framework launches the same OpenHands run and reuses the
scorers in scripts/run_pilot.py, so differences come from the framework layer only."""
import itertools
import json
import sys
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import run_pilot as rp  # noqa: E402

PROFILES = ["gpt-5.6-luna", "gpt-4.1-nano"]
CASE_IDS = ["P-01", "P-02", "P-03", "P-04", "P-05", "P-05b"]
_lock = threading.Lock()  # workspaces and the global profile are shared: serialize runs
_counters = {}
_state = {}


def _setup():
    if not _state:
        _state["cases"] = rp.load_cases()
        _state["local"] = json.loads(rp.LOCAL_FILE.read_text(encoding="utf-8"))
        _state["api"] = rp.Api("http://localhost:8000")
        _state["ops"] = rp.Ops(_state["api"], _state["local"]["ops_conversation_id"])


def case_prompt(case_id):
    _setup()
    return _state["cases"][case_id]["prompt"]


def execute(framework, case_id, profile, run_no=None):
    """Run one case through OpenHands and return the scored result dict."""
    _setup()
    with _lock:
        if run_no is None:
            c = _counters.setdefault((framework, case_id, profile), itertools.count(1))
            run_no = next(c)
        out = ROOT / "results" / "frameworks" / framework
        out.mkdir(parents=True, exist_ok=True)
        try:
            return rp.run_once(_state["api"], _state["ops"], _state["cases"][case_id], _state["local"],
                               profile, run_no, 600, out, tag=f"_{framework}")
        except SystemExit as e:
            return {"case_id": case_id, "classification": "harness_error", "valid": False, "error": str(e)}


def restore_default():
    api = rp.Api("http://localhost:8000")
    rp.configure_and_read_back(api, "gpt-4.1-nano")
