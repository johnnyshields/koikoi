---
description: Merge latest base branch into all worktrees (or specific ones)
---

## Variables

- **$REPO_ROOT** — `git rev-parse --show-toplevel`
- **$WORKTREE_BASE** — `$REPO_ROOT/../$(basename $REPO_ROOT)-worktree`
- **$DEFAULT_BRANCH** — `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'` (fallback: `main`)

`$ARGUMENTS` (optional): space-separated worktree names to sync. Empty = all.

If not inside tmux (`$TMUX` empty), print resume instructions and stop.

## Steps

1. **Fetch:** `git fetch origin $DEFAULT_BRANCH`

2. **Discover** worktrees under `$WORKTREE_BASE/`. If `$ARGUMENTS` set, filter to matching names.

3. **For each worktree** (sequentially):
   - Auto-commit any uncommitted changes
   - `git merge origin/$DEFAULT_BRANCH --no-edit`
   - If conflicts: `git merge --abort`, skip, move on. Never leave a worktree in conflicted state.

4. **Report:** synced, skipped (conflicts), skipped (errors).
