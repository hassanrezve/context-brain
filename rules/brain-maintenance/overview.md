# How to write into this brain — current-state reference, never a changelog

Every file is scoped to one topic and written as **current-state truth**. It is not a dated log of
what happened.

When a fix or rework supersedes something already documented, **edit that section in place**. If
text is fully obsolete but still worth keeping, move it to a short "Historical / superseded"
section at the bottom of the same file. Never add a new `## Fixed <date>` entry above the old one
and leave both standing.

**Why:** module files that grow by appending turn into thousand-line timelines. The same topic ends
up documented twice, once superseded and once current, told apart only by an inline note that is
easy to miss. Readers then have to wade through stale text to find what is true, and an agent may
act on the stale half.

## How to apply

- Before adding a dated "found and fixed" paragraph, check whether it reworks something already
  documented nearby. If so, edit that paragraph instead.
- Dates belong *inside* a statement when they record when a fact was verified or decided
  ("confirmed 2026-01-15", "owner, 2026-01-15"), not as headings that turn the file into a timeline.
- Git history answers "when did this change". The file answers "what is true now."
- When a file nears a few hundred lines and mixes unrelated topics, split it into sibling files
  with an `overview.md` that indexes them.
- Every topic is `<category>/<topic>/overview.md`. No bare `<category>/<topic>.md` files.
- A new topic needs the file **and** a pointer line in `CLAUDE.md`, which stays pointers-only.

## What makes a good entry

| Write it down | Leave it out |
|---|---|
| Why a decision was made, who made it, and what was rejected | What the code does: the code says that |
| A bug's root cause and the reasoning that failed | The fix itself: it is in git |
| A constraint that is invisible in the code | Who changed what and when: `git log` says that |
| A fact that is easy to get wrong or assume backwards | Anything you have not verified |
| A rule the team agreed on, with its reason | A restatement of a framework's own docs |

The test: **could someone derive this by reading the code?** If yes, it does not belong here.

## These conventions are enforced

The brain's `pre-commit` hook (source: `setup/hooks/pre-commit-brain`) blocks a commit whose staged
files break these rules:

| Blocked | Rule |
|---|---|
| A machine-specific absolute path | paths are derived or written relative to the brain |
| A `../<brain>/...` reference that does not resolve | no dead cross-references |
| A `## Fixed <date>` style heading | never a changelog |
| A bare `category/topic.md` file | the folder convention |
| A new `category/topic/overview.md` with no pointer in `CLAUDE.md` | no unreachable topics |

A date inside a descriptive heading ("— added 2026-01-08") is fine; only a heading that *is* a
dated change marker is rejected. Bypass: `git commit --no-verify`.

A hook was chosen over CI on purpose. CI reports a violation later, on the remote, to someone who
has to come back to it. A hook blocks it locally while the agent that caused it still has the
context to fix it.
