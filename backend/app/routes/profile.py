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
    languages: str = ""


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
def get_profile(current_user=Depends(get_current_user)):
    supabase = get_supabase_client(use_service_role=True)
    try:
        response = (
            supabase.table("profiles")
            .select(
                "name, personal_details, courses, interests, preferences, languages"
            )
            .eq("user_id", current_user.id)
            .maybe_single()
            .execute()
        )

        if response.data is None:
            raise HTTPException(status_code=404, detail="Profile not found")

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
        "languages": profile.languages,
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


class AvailabilityUpdate(BaseModel):
    availability_status: str


@router.get("/availability")
def get_availability(
    current_user=Depends(get_current_user)
):
    supabase = get_supabase_client(use_service_role=True)

    try:
        response = (
            supabase
            .table("profiles")
            .select("availability_status")
            .eq("user_id", current_user.id)
            .maybe_single()
            .execute()
        )

        if response.data is None:
            raise HTTPException(
                status_code=404,
                detail="Profile not found",
            )

        return {
            "availability_status": (
                response.data.get("availability_status") or "available"
            )
        }

    except HTTPException:
        raise

    except Exception as error:
        print("AVAILABILITY GET ERROR:", repr(error))
        raise HTTPException(
            status_code=500,
            detail="Could not retrieve availability",
        ) from error


@router.put("/availability")
def update_availability(
    payload: AvailabilityUpdate,
    current_user=Depends(get_current_user)
):
    status = payload.availability_status.strip().lower()

    if status not in {"available", "busy"}:
        raise HTTPException(
            status_code=422,
            detail="Availability must be 'available' or 'busy'",
        )

    supabase = get_supabase_client(use_service_role=True)

    try:
        response = (
            supabase
            .table("profiles")
            .update({"availability_status": status})
            .eq("user_id", current_user.id)
            .execute()
        )

        if not response.data:
            raise HTTPException(
                status_code=404,
                detail="Profile not found",
            )

        return {
            "message": "Availability updated successfully",
            "availability_status": status,
        }

    except HTTPException:
        raise

    except Exception as error:
        print("AVAILABILITY UPDATE ERROR:", repr(error))
        raise HTTPException(
            status_code=500,
            detail="Could not update availability",
        ) from error