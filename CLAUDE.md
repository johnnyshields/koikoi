# Koikoi - Japanese Matchmaking Dating App

## Project Structure
- `backend/` - Elixir/Phoenix API (no HTML/LiveView)
- `frontend/` - React + TypeScript + Vite SPA
- `lore/` - Architecture decision records

## Development Environment (WSL2)

### MongoDB Connection
MongoDB runs on the Windows host, NOT inside WSL. Always use the gateway IP:
```bash
export MONGODB_HOSTS="mongodb://$(ip route show default | awk '{print $3}'):27017"
```

For mix commands:
```bash
MONGODB_HOSTS="mongodb://$(ip route show default | awk '{print $3}'):27017" mix test
```

### Backend
```bash
cd backend
mix deps.get
mix test
mix phx.server  # starts on localhost:4000
```

### Frontend
```bash
cd frontend
npm install
npm run dev     # starts on localhost:5173
```

## Conventions

### Elixir/Phoenix
- Context modules in `lib/koikoi/` (Accounts, Profiles, Social, Matching, etc.)
- Controllers in `lib/koikoi_web/controllers/` return JSON only
- All API routes under `/api/v1/`
- JWT auth via Guardian - access tokens (15 min) + refresh tokens (30 days)
- Use `mongodb_ecto` for CRUD, raw `Mongo` driver for complex aggregation queries
- Background jobs via GenServer (no Oban - requires PostgreSQL)

### React/TypeScript
- Pages in `src/pages/`, shared components in `src/components/`
- API client in `src/api/` with JWT interceptor
- State management via Zustand stores in `src/store/`
- i18n via i18next, Japanese primary (`ja`), English secondary (`en`)
- Mobile-first responsive design with TailwindCSS

### Database (MongoDB)
- Separate `users` and `profiles` collections (security isolation)
- Canonical pair ordering: always `person_a_id < person_b_id`
- All collections use string IDs (MongoDB ObjectId as strings)

### i18n
- Japanese is the primary language
- All user-facing strings must go through i18n (Gettext backend, i18next frontend)
- Translation files: `backend/priv/gettext/{ja,en}/` and `frontend/public/locales/{ja,en}/`

### Testing
- Backend: `mix test` (ExUnit)
- Frontend: `npm test` (Vitest)
- Always write tests for new features
