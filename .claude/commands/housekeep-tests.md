---
description: Housekeep tests to stay current with code changes, fix stale tests, improve coverage
---

Review test suite for staleness, gaps, and quality issues, then fix and re-run.

**User argument: `$ARGUMENTS`**

## Step 0: Determine Scope

Read `.claude/housekeep_tests_state.json` to find the last commit this was run against.

The user may provide a scope argument. Interpret it as one of:

1. **Empty / no argument**: Use changes since `last_commit` in the state file. If the file doesn't exist or the commit is no longer in history, fall back to diffing the current branch vs master.
2. **A time expression** (e.g. "since yesterday", "last 3 days"): `git log --oneline --since="<date>"` to find relevant commits, then diff that range.
3. **A commit ref** (e.g. "abc1234", "HEAD~5"): `git diff <ref>..HEAD` for changes since that commit.
4. **A merged branch name** (e.g. "feature/chat-pivot"): Search `git log --oneline --all --grep="<branch>"` and `git log --oneline --merges` to find the merge commit and diff its changes.
5. **A feature/area name** (e.g. "shokai", "chat"): Search for both:
   - Recent commits mentioning the feature: `git log --oneline -30 --grep="<keyword>"`
   - Code files related to the feature: search `backend/lib/` and `backend/test/` for matching directories/files
   - If both code and recent commits are relevant, cover both. If ambiguous and non-overlapping, ask the user which scope they mean.

Once scope is determined, gather the relevant commits and changed files for the steps below.

## Step 1: Gather Context

```bash
# Use the range determined in Step 0 (examples below use <base>..HEAD)
git log --oneline <base>..HEAD
git diff <base>..HEAD --stat
git diff <base>..HEAD
```

Also read the test files that correspond to changed source files.

## Step 2: Audit Existing Tests for Staleness

For each changed source file, find its corresponding test file(s) and check:

- **Renamed/removed functions**: Tests referencing functions or modules that no longer exist or were renamed.
- **Changed signatures**: Tests calling functions with outdated argument lists or return types.
- **Changed behavior**: Tests asserting old behavior that no longer matches the implementation.
- **Dead test helpers**: Setup blocks or helpers that are no longer used by any test.
- **Stale imports**: Test files aliasing modules that were moved or deleted.
- **Skipped tests**: `@tag :skip` tests — check if the skip reason is still valid or if they can be unskipped.

Fix all stale tests found.

## Step 3: Identify Coverage Gaps

For changed source files, check what IS and ISN'T tested:

- **New functions**: Any new public function should have at least one test.
- **New branches**: New `case/cond/if` paths should be exercised.
- **New error handling**: New error tuples or raises should be tested.
- **Edge cases in changed logic**: Boundary conditions, empty inputs, nil values where applicable.
- **Integration points**: If new inter-context calls were added, verify integration coverage.

Do NOT go overboard — focus on meaningful gaps, not 100% line coverage. Prioritize:
1. Error paths and edge cases that could silently break
2. New public API surface
3. Complex branching logic

## Step 4: Check Test Quality

Review test files touched in scope for quality issues:

- **Overly broad assertions**: Tests that assert too little (e.g. just `assert result` instead of checking specific values).
- **Brittle assertions**: Tests that assert implementation details instead of behavior.
- **Test isolation**: Tests that depend on execution order or shared mutable state.
- **Unclear test names**: Test names that don't describe the scenario being tested.
- **Duplicated test logic**: Same setup/assertion pattern copy-pasted across tests that could share a setup block.

Fix issues that are clear improvements. Don't rewrite tests for style alone.

## Step 5: Add Missing Tests

Write tests for the gaps identified in Step 3. Follow project conventions:

- All tests use real MongoDB (never mock MongoDB).
- Use ExUnit with `async: false` for tests that touch the database.
- Place backend tests in `backend/test/koikoi/` mirroring `lib/koikoi/` structure.
- Keep tests focused — one behavior per test function.

## Step 6: Run Full Test Suite

**Backend:**
```bash
cd backend && mix test
```

**Frontend:**
```bash
cd frontend && npm test
```

All tests must pass. If new tests fail, fix them. If existing tests broke due to code changes discovered during this process, fix those too.

## Step 7: Update State File

After all tests pass, write `.claude/housekeep_tests_state.json`:

```json
{"last_commit": "<current HEAD full hash>", "last_run": "<ISO timestamp>"}
```

## Output

Summarize what you changed and what you flagged but didn't change. Be concise:

```
### Changed
- test/koikoi/chat_test.exs: fixed stale assertion after message type change
- test/koikoi/shokai_test.exs: added tests for expiration edge cases
- test/koikoi/social_test.exs: removed unused setup helper

### Flagged (no action taken)
- test/koikoi/matching_test.exs: @tag :skip "cold start not implemented" — still valid
- lib/koikoi/billing/billing.ex: new credit_check/1 has no tests (out of scope)
```
