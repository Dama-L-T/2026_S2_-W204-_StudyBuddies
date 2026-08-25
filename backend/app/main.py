from fastapi import FastAPI

from app.routes import health, study_buddies, auth, profiles

app = FastAPI(title="StudyBuddies API")

app.include_router(health.router)
app.include_router(study_buddies.router)
app.include_router(auth.router)
app.include_router(profiles.router)

@app.get("/")
def root():

    return {
        "message": "FastAPI backend is running"
    }