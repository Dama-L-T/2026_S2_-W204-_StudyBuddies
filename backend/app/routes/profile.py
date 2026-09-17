from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.services.auth_dependency import get_current_user
from app.services.supabase_service import get_supabase_client


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


@router.get("/status")
def get_profile_status(current_user=Depends(get_current_user)):
    supabase = get_supabase_client(use_service_role=True)

    response = (
        supabase
        .table("profiles")
        .select("user_id")
        .eq("user_id", current_user.id)
        .execute()
    )

    return {
        "profile_completed": len(response.data) > 0
    }


@router.post("/")
def save_profile(
    profile: Profile,
    current_user=Depends(get_current_user)
):
    supabase = get_supabase_client(use_service_role=True)

    profile_data = {
        "user_id": current_user.id,
        "name": profile.name,
        "personal_details": profile.personal_details,
        "courses": profile.courses,
        "interests": profile.interests,
        "preferences": profile.preferences,
    }

    try:
        response = (
            supabase
            .table("profiles")
            .upsert(profile_data)
            .execute()
        )

        return {
            "message": "Profile saved successfully",
            "profile": response.data,
        }

    except Exception as error:
        print("PROFILE SAVE ERROR:", repr(error))
        raise HTTPException(
            status_code=500,
            detail="Could not save profile",
        ) from error