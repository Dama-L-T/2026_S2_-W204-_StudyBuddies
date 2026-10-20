# Backend

FastAPI backend for StudyBuddies.

## Setup

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Fill in `backend/.env` with the shared Supabase values.

## Run

```bash
uvicorn app.main:app --reload
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

## Structure

- `app/main.py`: creates the FastAPI app and includes routers
- `app/config.py`: reads environment variables
- `app/routes/`: API endpoints
- `app/services/`: business logic and Supabase helpers
- `app/models/`: request and response models


## Assignment progress

Schedule create/update payloads accept `status`: `pending`, `in_progress`, or
`completed`. Flutter labels these Not Started, In Progress, and Completed.
The existing assignments.status text column stores the value; no schema change
is needed for the supplied schema. Explicit status takes precedence over the
legacy is_completed boolean, which remains supported for older clients.
Completed assignments continue to suppress reminders; reopening an assignment
as Not Started/In Progress permits reminder scheduling again.
