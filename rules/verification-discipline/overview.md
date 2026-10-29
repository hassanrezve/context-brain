# Verify before asserting — in docs and in fixes

One rule with two applications: **don't state something as true because it looks true or because
the mechanism suggests it should be.**

## 1. Before writing a claim into the brain

Before folding a claim from any outside source (a pasted notes file, an old doc, a memory, another
agent's summary) into a brain file, check it against the live repo: the file exists, the class,
method, column, config key or flag is really there.

**Why:** the brain is read as already-checked. One unverified claim written confidently does more
harm than a gap, because the next agent acts on it without looking.

**How to apply:** search for every path and name in the source before including it. Anything that
does not check out is dropped or explicitly flagged ("not verified: ..."), never silently included.

## 2. Before claiming a fix works

Do not diagnose a bug from a screenshot plus reading framework source and ship the fix on that
theory. Reproduce the broken state, apply the fix, and confirm the fixed state in the real thing.

**Why:** reading source to rule out a mechanism rules out *that mechanism only*. It says nothing
about adjacent layers (native browser behaviour, another component re-rendering, a cache, a
session) that can produce the same symptom. Server-rendered output cannot prove client-side
behaviour. A test that never calls the action it claims to cover proves nothing.

**How to apply:** treat "the source suggests X should happen" as a hypothesis. Say plainly what was
and was not checked when you report a fix.

## 3. Safeguards

A safeguard you wrongly trust is worse than none, because it changes how carefully you behave while
protecting nothing. Pipe-test every hook with a real payload before relying on it, and make tests
assert that the thing they judge actually happened (a file was staged, an action was called).
