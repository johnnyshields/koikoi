---
description: Commit and push to origin (no deploy)
args: "[branch-name]"
---

Commit all staged and unstaged changes and push to origin. Does NOT deploy to production.

**Optional argument:** `$ARGUMENTS` — a target branch name to push to. If provided, push to that branch instead of the current branch. If not provided (empty), push to the current branch.

**Worktree Handling:**
- If in a worktree, automatically creates and switches to a feature branch (feat-<descriptive-name>)
- Feature branch name is derived from the changes being committed
- Pushes to the feature branch, not master

**Steps:**

1. Determine target branch:
   - If `$ARGUMENTS` is non-empty, use that as the target branch name
   - Otherwise, use the current branch (default behavior)

2. Check if in worktree:
   ```bash
   pwd | grep -q worktree
   ```

3. If in worktree and no explicit branch argument, check current branch:
   ```bash
   git branch --show-current
   ```

4. If on master/main in worktree (and no explicit branch argument), create feature branch:
   - Analyze git status and diff to understand changes
   - Generate descriptive branch name: `feat-<short-description>`
   - Create and switch to feature branch:
     ```bash
     git checkout -b feat-<descriptive-name>
     ```

5. **Triage changes:**
   - Run `git status` and `git diff` to review all changed files
   - Group changes by topic/relevance
   - If ALL changes are clearly related to a single topic, stage them all
   - If there are **unrelated changes** (e.g., TODO.md edits, unrelated config changes, files from a different task), use the **AskUserQuestion tool** to ask the user which changes to include. Present the groups clearly (e.g., "Include TODO.md changes?" / "Include unrelated config edits?")
   - Stage the confirmed files and commit with descriptive message

6. Push to origin:
   ```bash
   git push -u origin <target-branch>
   ```

7. Inform user:
   - If feature branch created, tell them the branch name
   - Provide instructions to merge: "To merge to master: git checkout master && git merge feat-<name>"
