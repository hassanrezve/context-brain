"""SessionStart hook: keep this machine's brain current with the shared remote.

Auto-pulls ONLY when it is provably safe - clean working tree and a pure fast-forward - so nothing
local can be lost. Anything riskier (uncommitted edits, diverged history) is reported and left
alone: a hook must never clobber in-progress work or invent a merge.

Never blocks a session. An unreachable remote is reported, because "in sync" measured against a
stale ref would be a false reassurance.
"""
import json
import subprocess
import sys
from pathlib import Path

BRAIN = Path(__file__).resolve().parents[2]
NAME = BRAIN.name


def git(*args, timeout=10):
    return subprocess.run(["git", "-C", str(BRAIN), *args],
                          capture_output=True, text=True, timeout=timeout)


def emit(context):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }}))


try:
    if not (BRAIN / ".git").exists() or not git("remote").stdout.strip():
        sys.exit(0)

    fetch = git("fetch", "--quiet", timeout=15)

    if git("rev-parse", "--abbrev-ref", "@{u}").returncode != 0:
        emit(f"{NAME} has a remote but no upstream branch, so it is not syncing with anyone. "
             f"Set one with: git -C {NAME} push -u origin HEAD")
        sys.exit(0)

    counts = git("rev-list", "--left-right", "--count", "@{u}...HEAD")
    if counts.returncode != 0:
        sys.exit(0)
    behind, ahead = (int(n) for n in counts.stdout.split())

    if not behind and not ahead:
        if fetch.returncode != 0:
            emit(f"{NAME} could not reach the shared remote, so it may be behind without showing "
                 f"it. Re-check once connected: git -C {NAME} pull --rebase")
        sys.exit(0)

    dirty = bool(git("status", "--porcelain").stdout.strip())
    notes = []

    if behind and not ahead and not dirty:
        if git("merge", "--ff-only", "@{u}").returncode == 0:
            subjects = git("log", "--oneline", "-3", f"HEAD~{min(behind, 3)}..HEAD").stdout.strip()
            notes.append(f"{NAME} was {behind} commit(s) behind and has been fast-forwarded. Recent: "
                         + "; ".join(s.split(" ", 1)[-1] for s in subjects.splitlines()))
        else:
            notes.append(f"{NAME} is {behind} commit(s) behind and the fast-forward failed. "
                         f"Pull manually: git -C {NAME} pull --rebase")
    elif behind:
        why = "you have uncommitted changes" if dirty else f"your branch has diverged ({ahead} local commit(s))"
        notes.append(f"{NAME} is {behind} commit(s) BEHIND the shared remote and was NOT updated "
                     f"because {why}. Facts in it may already have been corrected by someone else. "
                     f"Resolve before relying on it: git -C {NAME} pull --rebase")

    if ahead:
        notes.append(f"{NAME} has {ahead} commit(s) not yet pushed: git -C {NAME} push")

    if notes:
        emit(" ".join(notes))
except Exception:
    pass  # never block a session on a sync check
sys.exit(0)
