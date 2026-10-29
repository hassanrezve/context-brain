"""Stop hook: get brain commits to the shared remote, or say clearly why they did not go.

Knowledge that is committed but never pushed reaches nobody, and forgetting to push is the default,
so this pushes rather than nagging. Uncommitted edits are normal mid-session and are never touched.

Safety: a plain push first. If the remote moved, the local commits are rebased on top; if that
cannot complete cleanly the rebase is ABORTED, leaving the repository exactly as it was. It never
force-pushes, never resolves a conflict itself, and never leaves a rebase in progress.
"""
import json
import subprocess
import sys
from pathlib import Path

BRAIN = Path(__file__).resolve().parents[2]
NAME = BRAIN.name


def git(*args, timeout=45):
    return subprocess.run(["git", "-C", str(BRAIN), *args],
                          capture_output=True, text=True, timeout=timeout)


def say(msg):
    print(json.dumps({"systemMessage": msg}))


def rebase_in_progress():
    return (BRAIN / ".git" / "rebase-merge").exists() or (BRAIN / ".git" / "rebase-apply").exists()


try:
    if not (BRAIN / ".git").exists() or not git("remote").stdout.strip():
        sys.exit(0)
    if git("rev-parse", "--abbrev-ref", "@{u}").returncode != 0:
        sys.exit(0)

    ahead = git("rev-list", "--count", "@{u}..HEAD")
    if ahead.returncode != 0:
        sys.exit(0)
    n = int(ahead.stdout.strip() or 0)
    if not n:
        sys.exit(0)

    subjects = git("log", "--oneline", "-3", "@{u}..HEAD").stdout.strip().splitlines()
    preview = "; ".join(s.split(" ", 1)[-1] for s in subjects)

    if git("push").returncode == 0:
        say(f"{NAME}: pushed {n} commit(s) ({preview}).")
        sys.exit(0)

    if git("status", "--porcelain").stdout.strip():
        say(f"{NAME}: {n} commit(s) not pushed - the remote moved and you have uncommitted changes, "
            f"so it was left alone. Commit or stash, then: git -C {NAME} pull --rebase && git -C {NAME} push")
        sys.exit(0)

    git("fetch", "--quiet")
    rebase = git("pull", "--rebase")

    if rebase.returncode != 0 or rebase_in_progress():
        if rebase_in_progress():
            git("rebase", "--abort")
        say(f"{NAME}: {n} commit(s) NOT pushed - someone else changed the same lines, so the rebase "
            f"was aborted and nothing changed. Resolve by re-verifying against the code, not by "
            f"picking the better-written version: git -C {NAME} pull --rebase")
        sys.exit(0)

    if git("push").returncode == 0:
        say(f"{NAME}: the remote had moved, so your {n} commit(s) were rebased on top and pushed ({preview}).")
    else:
        say(f"{NAME}: rebased onto the remote, but the push still failed. Check: git -C {NAME} push")
except Exception:
    pass  # never block a turn from ending
sys.exit(0)
