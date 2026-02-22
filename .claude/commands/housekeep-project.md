---
description: Housekeep project docs, CLAUDE.md, commands, and project config to stay current (project)
---

Perform a housekeeping pass to keep project documentation accurate and useful for Claude sessions.

**User argument: `$ARGUMENTS`**

## Step 0: Determine Scope

Read `.claude/housekeep_project_state.json` to find the last commit this was run against.

The user may provide a scope argument. Interpret it as one of:

1. **Empty / no argument**: Use changes since `last_commit` in the state file. If the file doesn't exist or the commit is no longer in history, fall back to `git log --oneline -30`.
2. **A time expression** (e.g. "since yesterday", "last 3 days"): `git log --oneline --since="<date>"` to find relevant commits.
3. **A commit ref** (e.g. "abc1234", "HEAD~5"): `git log --oneline <ref>..HEAD` for changes since that commit.
4. **A merged branch name** (e.g. "feature/chat-pivot"): Search `git log --oneline --all --grep="<branch>"` and `git log --oneline --merges` to find the merge commit and its changes.
5. **A feature/area name** (e.g. "shokai", "chat"): Search for both:
   - Recent commits mentioning the feature: `git log --oneline -30 --grep="<keyword>"`
   - Code files related to the feature: search `backend/lib/` and `frontend/src/` for matching directories/files
   - If both code and recent commits are relevant, cover both. If ambiguous and non-overlapping, ask the user which scope they mean.

Once scope is determined, gather the relevant commits and changed files for the steps below.

## Step 1: Gather Context

Read these sources to understand what has changed within scope:

1. **Commits in scope**: `git log --oneline` with appropriate range/filter from Step 0
2. **Diffs in scope**: `git diff <base>..HEAD --stat` to see what files changed
3. **Recent lore**: Read lore files whose dates fall within scope
4. **Current CLAUDE.md**: Read it fully
5. **Directory structure**: `find backend/lib/koikoi/ -type f -name "*.ex" | head -80` and `find frontend/src/ -type f -name "*.ts" -o -name "*.tsx" | head -80` to see current layout
6. **Current commands**: List `.claude/commands/` and skim any that look potentially stale

## Step 2: Update CLAUDE.md

Compare reality (from Step 1) against what CLAUDE.md says. Fix any drift:

- **Directory structure** — add new directories/files, remove deleted ones
- **Architecture descriptions** — update if new subsystems were added (e.g., new context module, new frontend pages)
- **Command reference** — ensure listed commands still work
- **Conventions** — add any new conventions established in recent lore (e.g., new patterns, new rules)
- **Collections** — add any new MongoDB collections
- Keep CLAUDE.md **concise and scannable** — it's a reference, not a narrative

## Step 3: Update Claude Commands (rarely)

Only touch `.claude/commands/` if:
- A command references paths/patterns that no longer exist
- A critical workflow changed (e.g., test command, build process)
- A new major workflow warrants a command

Do NOT rewrite commands for style. Leave them alone unless broken.

## Step 4: Prune Stale Lore

If any lore files are clearly superseded (e.g., a "plan" lore followed by an "implementation" lore for the same feature), note them but do NOT delete — just mention in output.

## Step 5: Check for Other Staleness

Look for other things that may drift:
- `TODO.md` — flag items that appear completed based on recent commits
- `backend/mix.exs` — check if description/metadata is still accurate
- `frontend/package.json` — check if scripts and dependencies are current
- `backend/config/` — flag if configs reference outdated settings

## Step 6: Update State File

After successful completion, write `.claude/housekeep_project_state.json`:

```json
{"last_commit": "<current HEAD full hash>", "last_run": "<ISO timestamp>"}
```

## Step 7: Write Lore

Write a lore file summarizing the housekeeping pass: `lore/YYYYMMDD-HHMM-housekeep-project-<scope>.md`

Include:
- Scope (commit range, number of commits)
- **Changed** section listing all files modified and what was done
- **Flagged** section listing issues noted but not actioned (stale TODOs, superseded lore, tech debt)

## Output

Summarize what you changed and what you flagged but didn't change. Be concise:

```
### Changed
- CLAUDE.md: added shokai/ to directory tree, updated chat section
- .claude/commands/test.md: updated MongoDB connection note

### Flagged (no action taken)
- lore/008-chat-centered-pivot-plan.md superseded by implementation
- TODO.md: "Instagram integration" item may need review
```
