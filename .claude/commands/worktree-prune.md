---
description: Clean up finished tmux panes/windows and their worktrees
args: "<prefix (optional) — clean up a specific group, or all if omitted>"
---

## Variables

- **$REPO_ROOT** — `git rev-parse --show-toplevel`
- **$WORKTREE_BASE** — `$REPO_ROOT/../$(basename $REPO_ROOT)-worktree`

If not inside tmux (`$TMUX` empty), print resume instructions and stop.

## Steps

### 1. Discover delegation groups

`git worktree list --porcelain` — find worktrees under `$WORKTREE_BASE/`, group by branch prefix (everything before the last `/`). If `$ARGUMENTS` set, filter to that prefix.

### 2. Assess status

For each group, check:
- **Tmux panes:** `tmux list-panes -a -F '#{pane_current_path} #{pane_id}'` — any active Claude processes in the worktrees?
- **Completion markers:** `.PHASE_0_COMPLETE`, `.HARDEN_COMPLETE`, `.MERGE_*_COMPLETE` in each worktree

A group is **prunable** if no active Claude processes are running, or if completion markers indicate the work finished.

### 3. Ask user

Use **AskUserQuestion**:
- Each prunable group: `"<prefix> (finished — N worktrees)"`
- `"All finished groups"` if multiple prunable
- Note any still-active groups

If nothing prunable, report and stop.

### 4. Clean up selected groups

For each selected group:
1. Kill tmux panes/windows in the group's worktrees
2. `git worktree remove <path> --force` for each worktree
3. `rm -rf $WORKTREE_BASE/<prefix>`
4. `git worktree prune`
5. Delete local branches matching `<prefix>/*` (NOT remote unless explicitly requested)

### 5. Report

Summary: groups cleaned, worktrees removed, branches deleted, any skipped.
