---
description: Commit only (no push, no deploy)
---

Commit all staged and unstaged changes locally. Does NOT push to origin or deploy to production.

**Worktree Handling:**
- If in a worktree, automatically creates and switches to a feature branch (feat-<descriptive-name>)
- Feature branch name is derived from the changes being committed
- Commits to the feature branch, not master

**Steps:**

1. Check if in worktree:
   ```bash
   pwd | grep -q worktree
   ```

2. If in worktree, check current branch:
   ```bash
   git branch --show-current
   ```

3. If on master/main in worktree, create feature branch:
   - Analyze git status and diff to understand changes
   - Generate descriptive branch name: `feat-<short-description>`
   - Create and switch to feature branch:
     ```bash
     git checkout -b feat-<descriptive-name>
     ```

4. **Triage changes:**
   - Run `git status` and `git diff` to review all changed files
   - Group changes by topic/relevance
   - If ALL changes are clearly related to a single topic, stage them all
   - If there are **unrelated changes** (e.g., TODO.md edits, unrelated config changes, files from a different task), use the **AskUserQuestion tool** to ask the user which changes to include. Present the groups clearly (e.g., "Include TODO.md changes?" / "Include unrelated config edits?")
   - Stage the confirmed files

5. Commit with descriptive message

6. Inform user:
   - If feature branch created, tell them the branch name
   - Remind them to push: `git push -u origin feat-<name>`
