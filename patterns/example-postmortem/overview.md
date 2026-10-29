# Postmortem — the safety hook that protected nothing

> Example entry. A real one from the brain's own history, kept generic.

**Symptom:** a hook meant to block destructive database commands let every command through.

**Root cause:** the hook parsed its JSON input with `jq`, which was not installed. It did not
error; the command substitution produced an empty string, the pattern match on an empty string
failed, and the hook exited 0 ("allow") every time.

**The reasoning that failed:** the hook was written, documented as installed, and looked right on
reading. Nobody fed it a real payload. It was trusted because it existed.

**Fix:** every hook parses JSON with `python3`, which fails loudly, and the guard **blocks** when it
cannot read its input (fail safe, not fail open). The installer pipe-tests the guard with one
destructive and one harmless command before it reports success.

**Lesson:** a safeguard you wrongly trust is worse than none. Pipe-test a hook before believing in
it. See `../context-brain/rules/verification-discipline/overview.md`.
