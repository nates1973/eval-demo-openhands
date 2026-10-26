import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import common  # noqa: E402


def call_api(prompt, options, context):
    vars_ = context.get("vars", {})
    r = common.execute("promptfoo", vars_["case_id"], vars_["profile"])
    return {"output": r.get("classification", ""),
            "metadata": {"valid": r.get("valid", True), "assertions": r.get("assertions"),
                         "conversation_id": r.get("conversation_id"), "cost_usd": r.get("cost_usd")}}
