---
description: Assess and auto-refactor if confident, then re-run tests (project)
---

## Phase 1: Assess

1. If there are uncommitted git changes, ask if I would like to commit first.

2. Enter plan mode (`EnterPlanMode` tool).

3. Review recent changes in the thread holistically. Look for:
   - Code duplication → consolidate / extract common module (do NOT go overboard with DRY)
   - Implementation inconsistencies, hacky/bloated/redundant code
   - Dead/unused/obsolete code → remove
   - Missing test coverage
   - Improve typespecs and documentation
   - Architectural improvements (not just surface-level fixes)
   - Do NOT go overboard or make performative suggestions

4. **Do hard refactors.** Do NOT preserve backward compatibility, especially of what you've recently implemented. Rename, restructure, break old code interfaces if needed.
   - Include explicit test coverage for everything you change.

5. Consider if docs need updating (raise as ask items): **CLAUDE.md** for conventions Claude needs to follow; **lore/** for implementation summaries. Not every change needs docs.

6. Write the plan to a lore file (`lore/YYYYMMDD-HHMM-description.md`).

   Include an **Effort/Impact Table** with ALL identified opportunities:

   | # | Opportunity | Effort | Impact | Action |
   |---|-------------|--------|--------|--------|
   | 1 | Description | Quick/Easy/Moderate/Hard | Low/Medium/High | Auto-fix / Ask first / Skip |

   Sort by effort (quick first). Number each item.

   Below the table, include **Opportunity Details** for each item:
   - **What**: The change
   - **Where**: Files/functions affected
   - **Why**: The value (maintainability, performance, correctness)
   - **Trade-offs**: Any downsides or risks (if applicable)

7. **At the end of the lore plan file**, include this section verbatim (survives context compression):

   ```markdown
   ## Execution Protocol
   **DO NOT implement any changes without user approval.**
   For EACH opportunity, use `AskUserQuestion`.
   Options: "Implement" / "Skip (add to TODO.md)" / "Do not implement"
   Ask all questions before beginning any implementation work
   (do NOT do alternating ask then implement, ask then implement, etc.)
   After all items resolved, run: `cd backend && mix test` + `cd frontend && npm test`
   ```

8. Exit plan mode (`ExitPlanMode` tool) for user approval.

## Phase 2: Execute (after plan approval)

**Read the lore plan file** to recover the opportunity list, then:

1. Create a task list (`TaskCreate`) with all identified opportunities.

2. For EACH opportunity (quick items first), use `AskUserQuestion` to ask:
   - Header: `#N [Effort]` (e.g., "#3 [Easy]")
   - Question: opportunity title + brief summary
   - Options: "Implement" / "Skip (add to TODO.md)" / "Do not implement"
   - Quick items may be batched into one multi-select `AskUserQuestion`.
   - **NEVER implement without asking first. WAIT for user response.**

3. Based on response:
   - **Implement**: make the change, do NOT reference item numbers in code comments.
   - **Skip**: add to TODO.md with lore file reference (e.g., `(lore/filename.md)`).
   - **Do not implement**: remove from task list.

4. **Parallelize with Agent Teams.** After all items are triaged, spawn teammates to implement approved items in parallel:
   - Group items by file ownership — each teammate owns distinct files (no overlapping edits).
   - Use `TeamCreate`, then `Task` tool with `team_name` to spawn teammates (use Sonnet unless the work needs Opus).
   - Each teammate gets: item description, files to edit, test command, and the instruction to NOT edit files outside their scope.
   - Wait for all teammates to finish, review their work, send feedback if needed.
   - If items are too tightly coupled to parallelize, implement sequentially instead.

5. After all items resolved, run tests: `cd backend && mix test` + `cd frontend && npm test`
