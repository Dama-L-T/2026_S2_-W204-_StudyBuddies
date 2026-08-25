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
