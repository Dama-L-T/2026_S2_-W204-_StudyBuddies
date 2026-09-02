from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes import auth, health, schedule

app = FastAPI(title="StudyBuddies API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(schedule.router)
app.include_router(auth.router)
