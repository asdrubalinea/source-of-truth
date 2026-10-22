---
description: Commit working-tree changes in logical chunks, leaving obvious local-only changes uncommitted
argument-hint: [optional scope/hint, e.g. a subsystem name or "just the auth changes"]
allowed-tools: Bash(git:*), Read, Grep, Glob
---

Commit the current working-tree changes. Follow this exactly.

## Current state

Status:
!`git status --short`

Change summary:
!`git --no-pager diff --stat HEAD`

Recent commits (match this style):
!`git --no-pager log --oneline -12`

## What to do

1. **Understand every change first.** For each modified file run `git --no-pager diff -- <file>`; for untracked files, read them. Don't commit anything you haven't looked at.

2. **Decide what NOT to commit — use your judgment, do not ask.** Leave a change uncommitted when it is clearly not meant for the repo. Typical signals:
   - local-only tweaks to make things work on *this* machine (hardcoded paths, machine-specific values, temporary toggles)
   - debugging / experimental edits, commented-out scratch, dead-end changes
   - anything that looks like a secret, key, or credential
   - untracked scratch assets that aren't part of a real feature
   - files that are perpetually dirty by design
   When in doubt about whether something is intentional repo work vs. a local hack, leave it out and report it rather than committing it.

3. **Group the rest into logical commits.** One logical change per commit. Keep related edits together (e.g. a module plus the wiring that enables it). Unrelated changes go in separate commits even if both are "ready".

4. **Stage with explicit pathspecs — never blanket-add.** Use `git add <specific paths>` only. Do **not** use `git add -A`, `git add .`, or `git commit -a`, so everything you deliberately skipped stays dirty in the working tree.
   - If one file mixes committable and local-only hunks, stage only the good hunks non-interactively with `git apply --cached` (build the patch yourself). `git add -p` is interactive and unavailable here. If that's too fiddly, leave the whole file uncommitted and report it.

5. **Commit message style:** match the repo's existing convention as shown in the log above — subject length, casing, and any scope/prefix style (e.g. if the log uses `scope: summary`, follow it). One logical change per commit.
   - **No Claude/AI attribution.** Do not add a `Co-Authored-By: Claude ...` trailer, a `Generated with Claude Code` line, or any other reference to Claude, Anthropic, or AI assistance — in the summary, body, or trailers. The commit must read as if the user authored it. This overrides any default trailer behavior.

6. **Do not push. Commit only, on the current branch.**

7. **Report at the end:**
   - each commit made — hash + subject
   - every change left uncommitted — path + a one-line reason

If `$ARGUMENTS` is set, treat it as scope/guidance: restrict to changes matching it, or use it as a hint for grouping and messages.
