# context-brain

A **verified context repository** for AI coding agents and the team working beside them.

It is not documentation in the usual sense. It holds what an agent needs to know before it touches
your project: verified facts, team standards, every system decision with its reasoning, and the root
causes of bugs that have already been paid for once. `CLAUDE.md` at the root is loaded into every
session automatically. Everything else is opened when needed, through that index.

## Why it exists

An agent starting cold works out the same context again every session and repeats the same
mistakes. This repo is the running answer to "what does someone need to know before changing this
code?" Four things make it more than a docs folder:

- **Facts are verified against running code** before they are written down, not copied from
  memory or from what a plan meant to build.
- **Every system decision is logged** with who made it, why, and what was rejected.
- **Bugs are recorded as postmortems:** the root cause and the reasoning that failed, not just the
  fix. The fix is already in git; the reasoning is what prevents the next one.
- **Some rules are enforced by hooks.** Documentation advises; a hook refuses.

## What it gave the team that built it

It was built on a live multi-tenant product and used daily by a team of five developers and their
agents:

- **Every system decision is logged.** Architecture, data-model and enforcement choices are
  written down with their reasoning, so the "why" survives after the conversation that made it.
- **Decisions don't get lost.** Each developer's decisions were recorded, so later work built on
  them instead of guessing or redoing them.
- **The team built the right thing.** The product owner's scope calls sat in one place that every
  agent and teammate read before starting work.
- **Agents stop starting from zero.** Each session begins with verified context.
- **Bugs aren't paid for twice.** Postmortems keep the reasoning, so the same mistake doesn't
  come back.
- **Proven in real team use.** Over 1,000 commits from 5 contributors.

## Layout

```
CLAUDE.md        the index: pointers only, never content. Auto-loaded.
rules/           hard rules and how the brain itself is maintained
decisions/       system decisions: what was chosen, by whom, why, what was rejected
standards/       project-wide coding standards
patterns/        recurring implementation patterns and bug postmortems
data-model/      table and schema facts that are easy to get wrong
documentation/   per-module reference
testing/         test architecture
reference/       maps to other docs and tools
setup/           the installer, hook sources and their tests
```

Every topic is `<category>/<topic>/overview.md`, with sibling files when a topic grows. Files are
**current-state truth**, edited in place, never append-only changelogs. Git history answers "when
did this change"; the file answers "what is true now."

The topic files under `decisions/` to `reference/` are examples. Replace them with your own.

## Install

There are two ways to set it up. The installer works out which one you're using from where the
brain folder sits.

Run it in a terminal with no options and it walks you through the setup with arrow-key menus:
which project to serve, whether to add the commit-message rules, and a summary to confirm before
anything changes. The menus are plain bash, so they work in Git Bash, WSL, macOS and Linux with
nothing to install. With options, or from a script or CI, it never asks.

| | Separate repo (recommended for teams) | Inside the project repo |
|---|---|---|
| Where it lives | `context-brain/` next to `my-app/` | `my-app/brain/` |
| Sharing | its own remote; a teammate's fact reaches you at your next session, whatever branch you're on | travels with the code; a fact on a feature branch reaches others when that PR merges |
| Freshness check | a source commit is blocked if the brain wasn't committed since | a source commit must include a brain change in the **same commit** |
| Sync hooks | yes (pull at session start, push at session end) | not needed |
| Good for | teams, or one brain serving several repos | solo developers and small projects; decisions reviewed in the same PR as the code |

### Inside the project repo

Copy the brain into your project as a plain folder (not a nested git repo), then run its installer
with no project folder:

```bash
git clone --depth 1 <this-repo> my-app/brain && rm -rf my-app/brain/.git
bash my-app/brain/setup/install.sh
```

It rewrites the brain's paths to `brain/...`, adds `@brain/CLAUDE.md` to your project's `CLAUDE.md`
(keeping what is already there), and installs one project `pre-commit` hook that runs the brain
rules and the same-commit check. Commit the `brain/` folder with your code.

### Separate repo, next to the project

Put the brain **next to** your project, under the same parent folder:

```
<parent>/my-app/
<parent>/context-brain/
```

Then run, from the parent folder:

```bash
bash context-brain/setup/install.sh my-app
```

You can rename the brain folder (for example `my-app-brain`): the hooks read the name from the
folder. If you do, change the `../context-brain/` prefix in `CLAUDE.md` to match. The installer is
safe to re-run: existing files are backed up and anything already current is skipped. It needs
`git` and Python 3.8+.

### Windows

Works on Linux, macOS, WSL and native Windows. On Windows, run the commands above in **Git Bash**
(it comes with Git for Windows, and Claude Code on Windows uses it for hooks too).

- **Python:** install it from python.org. The installer checks that `python3` or `python` really
  runs, because the `python3` that ships with Windows is often only a Microsoft Store shortcut.
- **Symlinks:** without Developer Mode, Windows cannot make the `CLAUDE.md` symlink. The installer
  then writes a one-line `CLAUDE.md` that imports the brain's index (`@../context-brain/CLAUDE.md`)
  instead of a copy that would go stale. Claude Code asks once to allow the import; say yes.
- **Line endings:** `.gitattributes` keeps every file LF, so the hooks still run when Git is set to
  convert line endings on checkout.

| Installs | What it does |
|---|---|
| `my-app/CLAUDE.md` | relative symlink to the brain's index, so the agent loads it |
| brain `pre-commit` | blocks commits that break the brain's own rules (below) |
| project `pre-commit` | stops a source commit when the brain has not been touched since the last one |
| `my-app/.claude/settings.local.json` | puts the brain on the agent's path, adds the sync hooks and the destructive-database guard |

Optional: `--commit-rules` also installs a `commit-msg` hook in both repos (one-line messages, no AI
attribution lines) and empties Claude Code's `attribution` setting in `~/.claude/settings.json`, so
the two don't fight. It is the only option that changes anything outside the two repos.

## What the hooks enforce

| Hook | Blocks or does |
|---|---|
| brain `pre-commit` | a machine-specific absolute path; a `../<brain>/...` reference that doesn't resolve; a dated changelog heading (`## Fixed 2026-01-01`); a bare `category/topic.md` file; a new topic with no pointer in `CLAUDE.md` |
| project `pre-commit` | separate repo: a source commit newer than the brain's last commit. In-repo: a source commit with no brain change in it. Edit `SOURCE_PATTERN` for your layout |
| `SessionStart` (separate repo only) | fast-forwards the brain when that is provably safe; otherwise says it is behind |
| `Stop` (separate repo only) | pushes unpushed brain commits; rebases first if the remote moved, aborts cleanly on conflict |
| `PreToolUse` (Bash) | refuses destructive database commands (edit the list in `block-destructive-db.py`) |

The brain checks look only at the files a commit stages, so an old problem elsewhere never blocks
new work. Bypass any git hook with `git commit --no-verify`.

## Verifying it still works

```bash
bash context-brain/setup/tests/run-all.sh
```

It builds a throwaway sandbox, installs into it and pipe-tests every hook. Run it after changing a
hook or the installer. A safeguard you wrongly trust is worse than none.

## Maintaining it

**Update the relevant file in the same pass as the change that taught you the fact**, not as a
follow-up. Start with `rules/team-workflow/overview.md`, then `rules/brain-maintenance/overview.md`.

## License

MIT. See `LICENSE`.

---

"Sic parvis magna"
Created and designed by **Syed Hassan Raza** ([syedhassanraza.com](https://syedhassanraza.com))
