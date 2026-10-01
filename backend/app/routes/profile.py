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
def get_profile_status(
    current_user=Depends(get_current_user)
):
    supabase = get_supabase_client(use_service_role=True)

    try:
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

    except Exception as error:
        print("PROFILE STATUS ERROR:", repr(error))

        raise HTTPException(
            status_code=500,
            detail="Could not check profile status",
        ) from error


@router.get("/")
def get_profile(
    current_user=Depends(get_current_user)
):
    supabase = get_supabase_client(use_service_role=True)

    try:
        response = (
            supabase
            .table("profiles")
            .select(
                "name, personal_details, courses, interests, preferences"
            )
            .eq("user_id", current_user.id)
            .maybe_single()
            .execute()
        )

        if response.data is None:
            raise HTTPException(
                status_code=404,
                detail="Profile not found",
            )

        return response.data

    except HTTPException:
        raise

    except Exception as error:
        print("PROFILE GET ERROR:", repr(error))

        raise HTTPException(
            status_code=500,
            detail="Could not retrieve profile",
        ) from error


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
            .upsert(
                profile_data,
                on_conflict="user_id"
            )
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