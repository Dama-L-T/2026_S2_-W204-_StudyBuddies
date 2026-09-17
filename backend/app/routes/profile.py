from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(
    prefix="/profile",
    tags=["Profile"]
)


class Profile(BaseModel):
    name: str
    personal_details: str = ""
    courses: str = ""
    interests: str = ""
    preferences: str = ""


@router.post("/")
def save_profile(profile: Profile):
    return {
        "message": "Profile received successfully",
        "profile": profile.model_dump()
    }


@router.get("/{name}")
def get_profile(name: str):
    return {
        "message": "Profile requested",
        "name": name
    }

