---
description: Pull latest master into the current branch without switching branches
---

Pull the latest master into the current branch. Never switches branches — uses fetch + merge.

## Steps

1. **Show current branch:**
   ```bash
   git branch --show-current
   ```

2. **Check for uncommitted changes.** If there are any, commit them first with a descriptive message (stage + commit).

3. **Pull latest master into the current branch:**
   ```bash
   git fetch origin master
   git merge origin/master
   ```

4. **If merge conflicts occur:**

   a. Check the conflicted files:
      ```bash
      git diff --name-only --diff-filter=U
      ```

   b. Read each conflicted file and assess complexity:
      - **Trivial conflicts** (whitespace, non-overlapping changes, simple additions): resolve automatically and continue.
      - **Non-trivial conflicts** (overlapping logic changes, semantic conflicts, deletions vs modifications): **ask the user** before proceeding. Present the conflicts clearly and offer these options:
        1. **Resolve conflicts (Recommended)** — fix the conflicts and complete the merge commit.
        2. **Abort** — run `git merge --abort`.

   c. After resolving, stage and complete the merge:
      ```bash
      git add <resolved-files>
      git commit
      ```

5. **Report result** — confirm what happened: merge outcome, number of commits pulled in, and current state.
