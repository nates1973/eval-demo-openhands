"""Inspect AI task. The model is a placeholder (mockllm); the solver launches OpenHands
and the scorer maps the existing oracle classification to a score.

  inspect eval frameworks/inspect-ai/pilot_task.py -T profile=gpt-5.6-luna --epochs 3 \
      --model mockllm/model --max-samples 1 --max-tasks 1
"""
import sys
from pathlib import Path

from inspect_ai import Task, task
from inspect_ai.dataset import MemoryDataset, Sample
from inspect_ai.scorer import CORRECT, INCORRECT, NOANSWER, Score, accuracy, scorer
from inspect_ai.solver import Generate, TaskState, solver

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import common  # noqa: E402


@solver
def openhands_solver(profile):
    async def solve(state: TaskState, generate: Generate):
        r = common.execute("inspect", state.sample_id, profile)
        state.metadata["result"] = r
        state.output.completion = str(r.get("classification", ""))
        return state
    return solve


@scorer(metrics=[accuracy()])
def oracle_scorer():
    async def score(state: TaskState, target):
        r = state.metadata["result"]
        cls = r.get("classification")
        if not r.get("valid", True) or cls == "not_exercised":
            return Score(value=NOANSWER, answer=str(cls), explanation=str(r.get("error_excerpt") or cls))
        return Score(value=CORRECT if cls == "pass" else INCORRECT, answer=str(cls),
                     explanation=str(r.get("assertions")))
    return score


@task
def pilot(profile: str = "gpt-5.6-luna"):
    samples = [Sample(id=c, input=common.case_prompt(c), target="pass") for c in common.CASE_IDS]
    return Task(dataset=MemoryDataset(samples), solver=openhands_solver(profile), scorer=oracle_scorer())
