---
description: Fix linting issues and warnings, then re-run tests (project)
---

Run formatters and linters:

**Backend (Elixir):**
```bash
cd backend && mix format
cd backend && mix compile --warnings-as-errors
```

**Frontend (TypeScript):**
```bash
cd frontend && npx tsc --noEmit
cd frontend && npm run lint -- --fix 2>/dev/null || true
```

Fix all issues and all warnings in the output (do not suppress them). Focus on getting all linter and warnings fixed.

Ignore any line-ending (CR-LF) warnings; these are just because we are using a Windows filesystem locally, but Git will handle them when we commit.

After linting is complete, re-run tests if there have been significant changes:

**Backend:**
```bash
cd backend && mix test
```

**Frontend:**
```bash
cd frontend && npm test
```
