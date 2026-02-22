---
description: Run tests with coverage and increase coverage (project)
---

1. Run tests with coverage:

   **Backend:**
   ```bash
   cd backend && mix test --cover
   ```

   **Frontend:**
   ```bash
   cd frontend && npx vitest run --coverage
   ```

2. Check coverage output for files with missing lines
3. Identify files with missing coverage from the output.
4. Add tests for all identified files with missing coverage.
   - Do NOT rerun coverage until you've made an attempt at improving ALL relevant files.
   - If in context of recent work, prioritize files touched in that work.
   - If you find bona-fide dead code paths (100% sure), remove them.
   - If general coverage request, prioritize files with lowest coverage.
5. Re-run coverage to verify improvements.
6. Repeat steps 3-5 until coverage targets are met or no further improvements possible.
