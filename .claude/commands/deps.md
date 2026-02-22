---
description: Update dependencies (project)
---

Update project dependencies:

1. Check for outdated packages:

   **Backend:**
   ```bash
   cd backend && mix hex.outdated
   ```

   **Frontend:**
   ```bash
   cd frontend && npm outdated
   ```

2. Update all dependencies:

   **Backend:**
   ```bash
   cd backend && mix deps.update --all
   ```

   **Frontend:**
   ```bash
   cd frontend && npm update
   ```

3. Run verification:

   **Backend:**
   ```bash
   cd backend && mix test
   ```

   **Frontend:**
   ```bash
   cd frontend && npm test
   ```

4. Fix any breaking changes
