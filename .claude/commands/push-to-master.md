---
description: Push current changes to master branch
---

Push the current branch to master on origin. Pulls latest master first and resolves conflicts if needed. Never switches branches. **NEVER use force push (`--force` or `-f`)** — if the push is rejected, investigate and resolve the issue instead.

## Steps

1. **Check for uncommitted changes.** If there are any:
   - **Triage changes:** Group changes by topic/relevance. If there are **unrelated changes** (e.g., TODO.md edits, unrelated config changes, files from a different task), use the **AskUserQuestion tool** to ask the user which changes to include before staging.
   - Stage the confirmed files and commit with a descriptive message.

2. **Pull latest master into the current branch:**
   ```bash
   git fetch origin master
   git merge origin/master
   ```

3. **If merge conflicts occur:**

   a. Check the conflicted files:
      ```bash
      git diff --name-only --diff-filter=U
      ```

   b. Read each conflicted file and assess complexity:
      - **Trivial conflicts** (whitespace, non-overlapping changes, simple additions): resolve automatically and continue.
      - **Non-trivial conflicts** (overlapping logic changes, semantic conflicts, deletions vs modifications): **ask the user** before proceeding. Present the conflicts clearly and offer these options:
        1. **Resolve conflicts but don't push (Recommended)** — fix the conflicts, complete the merge commit, but stop before pushing so the user can review.
        2. **Resolve conflicts and push** — fix everything and push to origin.
        3. **Abort** — run `git merge --abort`.

   c. After resolving, stage and complete the merge:
      ```bash
      git add <resolved-files>
      git commit
      ```

4. **Push to master** (skip if user chose "resolve but don't push"):
   ```bash
   git push origin HEAD:master
   ```

5. **Report result** — confirm what happened: merge outcome, whether pushed, and current state.
