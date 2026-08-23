from fastapi import FastAPI

from app.routes import health, study_buddies

app = FastAPI(title="StudyBuddies API")

app.include_router(health.router)
app.include_router(study_buddies.router)
