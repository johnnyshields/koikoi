---
description: Review all code changes holistically for code smells, fix lint errors, etc.
---

Review code changes holistically for code quality issues, fix lint errors, and ensure tests pass.

**User argument: `$ARGUMENTS`**

## Step 0: Determine Scope

Read `.claude/housekeep_code_state.json` to find the last commit this was run against.

The user may provide a scope argument. Interpret it as one of:

1. **Empty / no argument**: Use changes since `last_commit` in the state file. If the file doesn't exist or the commit is no longer in history, fall back to diffing the current branch vs master.
2. **A time expression** (e.g. "since yesterday", "last 3 days"): `git log --oneline --since="<date>"` to find relevant commits, then diff that range.
3. **A commit ref** (e.g. "abc1234", "HEAD~5"): `git diff <ref>..HEAD` for changes since that commit.
4. **A merged branch name** (e.g. "feature/chat-pivot"): Search `git log --oneline --all --grep="<branch>"` and `git log --oneline --merges` to find the merge commit and diff its changes.
5. **A feature/area name** (e.g. "shokai", "chat system"): Search for both:
   - Recent commits mentioning the feature: `git log --oneline -30 --grep="<keyword>"`
   - Code files related to the feature: search `backend/lib/` and `frontend/src/` for matching directories/files
   - If both code and recent commits are relevant, cover both. If ambiguous and non-overlapping, ask the user which scope they mean.

Once scope is determined, gather the relevant commits and changed files for the steps below.

## Step 1: Gather changes

```bash
# Use the range determined in Step 0 (examples below use <base>..HEAD)
git log --oneline <base>..HEAD
git diff <base>..HEAD --stat
git diff <base>..HEAD
```

## Step 2: Run linters and fix all errors

**Backend:**
```bash
cd backend && mix format
cd backend && mix compile --warnings-as-errors
```

**Frontend:**
```bash
cd frontend && npx tsc --noEmit
```

Fix any non-autocorrected issues manually.

## Step 3: Review for code smells

Review all changed files (within scope) for:

- **Single Responsibility violations**: Controller concerns (request parsing, response formatting) should stay in controllers. Domain logic (matchmaking, social graph) should stay in context modules. Pass structured results across boundaries, not raw data.
- **Unnecessary complexity**: Overly complex conditionals, deeply nested code, unclear control flow.
- **Code duplication**: Same logic in multiple places that should be consolidated.
- **Inconsistent patterns**: Similar operations handled differently in different places.
- **Dead code**: Unused imports, variables, functions, or unreachable code paths.
- **Missing error handling**: Unhandled error tuples at system boundaries.
- **Missing typespecs**: Missing `@spec` on public functions.
- **Naming issues**: Unclear variable/function names, inconsistent naming conventions.
- **BSON.ObjectId handling**: Ensure ObjectIds are properly converted to strings before JSON encoding, and string IDs are decoded with `BSON.ObjectId.decode/1` before querying.
- **Frontend type safety**: Missing TypeScript types, `any` usage, unchecked API responses.

## Step 4: Fix issues

Fix all identified issues. For each fix, ensure it doesn't break existing behavior.

## Step 5: Re-run tests

**Backend:**
```bash
cd backend && mix test
```

**Frontend:**
```bash
cd frontend && npm test
```

All tests must pass after changes.

## Step 6: Update State File

After all tests pass, write `.claude/housekeep_code_state.json`:

```json
{"last_commit": "<current HEAD full hash>", "last_run": "<ISO timestamp>"}
```

## Step 7: Write Lore

Write a lore file summarizing the housekeeping pass: `lore/YYYYMMDD-HHMM-housekeep-code-<scope>.md`

Include:
- Scope (commit range, number of commits, key areas touched)
- **Lint fixes** — summary of what was fixed
- **Code smells found and fixed** — brief list of each refactor
- **Flagged but not fixed** — issues noted for future attention
- **Test results** — confirm all tests pass
