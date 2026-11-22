# CLAUDE.md — Project Index

The entry point for AI agents in this project. Reference content (verified facts, decisions,
standards, bug postmortems) lives in topic files under `../context-brain/`. This page is a table of
contents: open the linked file before working in that area, don't guess.

Every path below is relative to the project root, where the agent works. Open paths exactly as
written. They hold no machine-specific home directory, so they work on every machine.

This index is for every AI agent, not only Claude Code. The file name `CLAUDE.md` is historical:
Claude Code reads it automatically, and Codex and other agents reach it through `AGENTS.md`.

**Never put content in this file.** Add a topic file, then a one-line pointer here.

## Priority while working

1. The topic files below: this project's own verified facts and decisions.
2. The framework's own documentation, for anything the brain does not cover.
3. Where the brain and the running code disagree, the code wins. Fix the brain file in the same
   session you noticed.

## Rules

- How to write into the brain (current state, never a changelog): `../context-brain/rules/brain-maintenance/overview.md`
- Verify before asserting, in docs and in fixes: `../context-brain/rules/verification-discipline/overview.md`
- Team workflow, the daily loop and how to resolve a conflict: `../context-brain/rules/team-workflow/overview.md`

## Decisions

- Example decision record (copy its shape): `../context-brain/decisions/example-decision/overview.md`

## Standards

- Example standard: `../context-brain/standards/example-standard/overview.md`

## Patterns and postmortems

- Example postmortem: `../context-brain/patterns/example-postmortem/overview.md`

## Data model

- Example table facts: `../context-brain/data-model/example-table/overview.md`

## Module documentation

- Example module: `../context-brain/documentation/example-module/overview.md`

## Testing

- Test architecture: `../context-brain/testing/test-architecture/overview.md`

## Reference

- Map of other docs and tools: `../context-brain/reference/documentation-map/overview.md`
