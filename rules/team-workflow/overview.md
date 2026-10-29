# Team workflow — operating the brain day to day

How a team sets up, uses and maintains the brain. For *what makes a good entry*, see
`../context-brain/rules/brain-maintenance/overview.md`; this file is about process.

The brain is shared through one remote that everyone works against. One failure mode matters more
than all the others:

> **A stale brain is worse than no brain, because it is trusted.** Ordinary docs quietly go out of
> date. This one gets *believed*: an agent reads a corrected-but-not-pulled fact as verified truth
> and acts on it.

## 1. One-time setup, per person

Clone the brain next to the project and run the installer:

```
git clone <brain-remote> context-brain
bash context-brain/setup/install.sh <project-folder>
```

Then start a session and confirm the index is in context.

## 2. The daily loop

| When | What happens | Who |
|---|---|---|
| Session start | The brain fast-forwards if you are behind and your tree is clean | Automatic |
| During work | You learn something, make a decision, fix a documented bug or find a stale fact | You and the agent |
| Same pass | The owning topic file is edited **in place** | You and the agent |
| Session end | Brain commits are pushed; if the remote moved they are rebased on top first | Automatic |
| Session end | If that cannot be done safely, it stops and says why | You resolve |

Long sessions are the weak spot: the pull runs when a session *starts*. Start a fresh session now
and then to pick up teammates' changes.

## 3. Logging decisions

Every decision that shapes the system goes into the brain the moment it is made: a product owner's
scope call, a naming choice, an architecture trade-off, a rule the team agreed on. Record **who**
decided, **when**, **why**, and **what was rejected**. Put it in the topic file it affects, or in
`decisions/` when it spans several. This is what lets later work build on a decision instead of
guessing at it or quietly reversing it.

## 4. Do

- **Verify before writing.** Search for the path, class, column or flag before stating it.
- **Update in the same pass** as the change that taught you the fact, never as a follow-up.
- **Edit in place.** Supersede old text; don't stack a dated entry on top of it.
- **One topic per file**, at `<category>/<topic>/overview.md`, with a pointer in `CLAUDE.md`.
- **Record the reasoning that failed**, not just the conclusion.

## 5. Don't

- **Don't write an unverified claim.** It destroys the brain's value.
- **Don't put content in `CLAUDE.md`.** It is an index.
- **Don't hard-code an absolute path** in a doc, hook or script. It works on one machine only.
- **Don't branch the brain.** It has one branch, `main`, even while the project is on a feature
  branch. Brain branches named after feature branches strand knowledge that never reaches `main`.
- **Don't ignore a "could not be pushed" message.** Your knowledge is still only on your machine.
- **Don't document a module from its plan.** Read what was actually built.

## 6. Conflicts

A conflict means two people documented the same fact differently. Resolve it by **re-verifying
against the running code**, not by picking the better-written paragraph.

- One statement checks out, the other doesn't: keep the verified one.
- Both check out: both are true under different conditions. Keep both and state the condition.
- Neither checks out: delete both and write what you actually observed.
- Two people only added different lines at the same spot: keep both.

## 7. When something looks wrong

| Symptom | Likely cause |
|---|---|
| Index not in context | `CLAUDE.md` symlink missing or broken: re-run the installer |
| Hooks not firing | Settings changed after the session started: restart it |
| First project commit after install is rejected by the brain check | Expected. Document the change and commit the brain, or `--no-verify` |
| A documented fact contradicts the code | The code wins. Fix the file now |
