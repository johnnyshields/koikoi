---
description: Delegate a task to a supervisor Claude in a tmux pane
args: "<task description | branch: task | ROADMAP_N.md>"
---

## Variables

- **$REPO_ROOT** — `git rev-parse --show-toplevel`
- **$REPO_NAME** — basename of $REPO_ROOT
- **$WORKTREE_BASE** — `$REPO_ROOT/../$REPO_NAME-worktree`
- **$SESSION_ID** — current Claude session ID
- **$PREFIX** — derived from $ARGUMENTS (see Step 1)
- **$TASK_DIR** — `$WORKTREE_BASE/$PREFIX`

**User argument: `$ARGUMENTS`**

## Architecture

```
Master (this command) — setup + launch, then exit
  └─ Supervisor (tmux pane) — research, plan, implement or delegate, harden, finalize
       ├─ Teammate 1 (Agent Teams)
       ├─ Teammate 2 (Agent Teams)
       └─ ...
```

---

## Step 0: Require tmux

If `$TMUX` is empty, print this and **stop**:

```
Not inside tmux. Run:
tmux new-session -A -s $REPO_NAME -c $REPO_ROOT \; send-keys 'claude --resume $SESSION_ID' Enter
```

---

## Step 1: Derive PREFIX

No research, no questions — just string processing.

- `$ARGUMENTS` matches `ROADMAP_N.md` → slugify the file's `# Title` heading
- `$ARGUMENTS` contains `:` with a branch-name-like prefix → use that prefix
- Otherwise → extract key words (skip stop words), join with hyphens, prefix with `feat-`/`fix-`/`refactor-`
- Empty → infer from conversation context

---

## Step 2: Create supervisor worktree

```bash
mkdir -p $TASK_DIR
git worktree add $TASK_DIR/supervisor -b $PREFIX/supervisor
```

---

## Step 3: Write supervisor YOUR_TASK_0.md

Write `$TASK_DIR/supervisor/YOUR_TASK_0.md` using the **Supervisor Template** below. Substitute all variables and paste `$ARGUMENTS` verbatim into the task description.

If the user provided special instructions beyond the task description, include them in a `## Claude Instructions` section. The supervisor must propagate these to teammates.

If `$ARGUMENTS` is a roadmap file, also include the **Roadmap Addendum**.

---

## Step 4: Launch supervisor

```bash
tmux new-window -n "${PREFIX}-super" -c "$TASK_DIR/supervisor" \
"cd $TASK_DIR/supervisor && CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --dangerously-skip-permissions '/tmux-do-task'"
```

---

## Step 5: Report & exit

```
Supervisor launched: $PREFIX/supervisor ($TASK_DIR/supervisor)

To watch: switch to the supervisor pane
To clean up when finished: /tmux-prune
```

---
---

## Supervisor Template

> Copy verbatim (with variable substitution) into YOUR_TASK_0.md.

````markdown
# Task: Supervisor — $PREFIX

> **Branch:** $PREFIX/supervisor
> **Role:** SUPERVISOR

## Task Description

<paste $ARGUMENTS verbatim>

## Claude Instructions

<Paste user's special instructions here, or omit section if none. Propagate to teammates.>

## Environment

| Variable | Value |
|----------|-------|
| REPO_ROOT | $REPO_ROOT |
| PREFIX | $PREFIX |

Working directory: `$TASK_DIR/supervisor` (git worktree on branch `$PREFIX/supervisor`)

## Lifecycle

1. **Research & Plan** — explore codebase, design via plan mode, get user approval
2. **Implement** — solo (simple tasks) or delegate to teammates (complex/parallelizable)
3. **Harden** — holistic review, cleanup, add missing tests
4. **Finalize** — lint, test, commit
5. **Merge** — PR, direct merge, or skip

---

## 1. Research & Plan

Research the task before planning:
- Read `$REPO_ROOT/CLAUDE.md` for project conventions
- Explore codebase — file structure, naming patterns, existing features
- Read reference files (similar handlers, templates, etc.)
- Fetch any URLs in the task description

Use **EnterPlanMode**. Write the plan as a lore file (`$REPO_ROOT/lore/YYYYMMDD-HHMM-$PREFIX-plan.md`).

The plan must cover:
1. **Research findings**
2. **Implementation strategy** — solo or teammates?
   - **Solo:** simple, tightly-coupled, or few files
   - **Teammates:** 3+ independent pieces that can be parallelized
   - If teammates: how many, what each does, which files each owns (no overlapping edits)
3. **Shared contracts** (if teammates) — model structs, API endpoints, function signatures
4. **Design decisions** — key choices and rationale

Use **ExitPlanMode** for user approval.

---

## 2. Implement

**Solo:** implement the plan directly.

**With teammates:** give each a clear, self-contained description (files to own, contracts, tests, propagated Claude Instructions). Each teammate must own distinct files — no overlapping edits. Use Sonnet unless the work needs Opus. Wait for completion, review, send feedback, iterate until satisfied.

---

## 3. Harden

Review all changes holistically. Fix automatically:
- Code duplication, inconsistent naming, dead code
- Missing edge-case tests, uncovered code paths
- Integration issues between contributions
- Overly complex logic that can be simplified

Run tests and lint to verify.

---

## 4. Finalize

1. If teammates were used, clean up the team
2. **Lint** — per CLAUDE.md. Fix all issues.
3. **Test** — all must pass. Fix and repeat until green.
4. **Commit** — descriptive message covering all changes.

---

## 5. Merge

Print a summary (branch, changes, test/lint status).

Ask the user (via **AskUserQuestion**) whether to: create a PR (recommended), merge directly into $DEFAULT_BRANCH, or skip. Then do it.

Print `To clean up: /tmux-prune`
````

---

## Roadmap Addendum

If `$ARGUMENTS` matches `ROADMAP_N.md`, append to Phase 1 in the supervisor template:

```markdown
### Roadmap Mode

Instead of decomposing the task yourself:

1. Read the roadmap file at `$REPO_ROOT/<filename from $ARGUMENTS>`
2. Parse nodes: each `### node-id: Title` section has Status, Depends on, Phase, Engine, Description, Acceptance criteria
3. Spawnable = status `ready` + all dependencies `done`
4. Create one teammate per spawnable node (include Node ID, Phase, Engine, Description, Acceptance Criteria in prompt)
5. Update spawned nodes from `ready` to `spawned` in the roadmap file
```
