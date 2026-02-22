---
description: Universal entry point for tmux-delegate roles (supervisor or worker)
---

## Setup

Read `YOUR_TASK_0.md` from the current directory (fallback: `YOUR_TASK.md`). If neither exists:

```
Error: No YOUR_TASK_0.md found. Run /tmux-delegate first, then cd into a worktree.
```

Look for `> **Role:**` near the top:
- `SUPERVISOR` → **Supervisor Lifecycle**
- Anything else → **Worker Lifecycle**

Arguments: `$ARGUMENTS` = `plan-only` stops workers after planning.

---

## Supervisor Lifecycle

Read CLAUDE.md, then follow YOUR_TASK_0.md exactly. Do NOT enter the worker lifecycle.

---
---

## Worker Lifecycle

```
Implementation Phases (YOUR_TASK_0, 1, 2, ...)
  → Harden
    → Merge Phases (YOUR_MERGE_0, 1, ...)
      → Finalize (Lint → Test → Commit → Push)
```

At each checkpoint, signal completion and wait up to 10 minutes for the next instruction file. If none appears, advance to the next stage.

### 1. Read reference files

- `CLAUDE.md` — source of truth for build, test, lint commands
- `lore/` — recent implementation summaries

### 2. Implementation phase loop

Set `N = 0`. Loop:

**2a.** Read `YOUR_TASK_{N}.md`. For N=0: enter plan mode, write a lore file, implement with tests. If `$ARGUMENTS` = `plan-only`, stop here. For N>0: apply requested changes without re-planning.

**2b.** Run tests and lint per CLAUDE.md. Fix until clean.

**2c.** Signal: `touch .PHASE_{N}_COMPLETE`

**2d.** Poll for `YOUR_TASK_{N+1}.md` every 10s, up to 10 min. Found → increment N, loop. Timeout → proceed to Harden.

---

### 3. Harden

Review all changes holistically. Fix automatically:
- Code duplication, inconsistent naming, dead code
- Missing edge-case tests, uncovered code paths
- Overly complex logic that can be simplified

Run tests and lint. Fix until clean.

Signal: `touch .HARDEN_COMPLETE`

Poll for `YOUR_MERGE_0.md` every 10s, up to 10 min. Found → Merge. Timeout → Finalize.

---

### 4. Merge phase loop

Set `M = 0`. Loop:

**4a.** Read `YOUR_MERGE_{M}.md` — which branch to merge and conflict resolution guidance.

**4b.** `git fetch origin <source-branch> && git merge origin/<source-branch>`. Resolve conflicts per guidance. Fix integration issues.

**4c.** Run tests and lint. Fix until clean.

**4d.** Signal: `touch .MERGE_{M}_COMPLETE`

**4e.** Poll for `YOUR_MERGE_{M+1}.md` every 10s, up to 10 min. Found → increment M, loop. Timeout → Finalize.

---

### 5. Finalize

1. **Lint** — per CLAUDE.md. Fix all issues.
2. **Test** — all must pass. Fix and repeat until green.
3. **Commit** — descriptive message covering all changes.
4. **Push** — `git push -u origin <branch>`

Report: branch, files changed, test/lint status.
