from fastapi import APIRouter, HTTPException

from app.schemas.profile import ProfileUpdateRequest

from app.services.profile_service import (
    get_profile,
    update_profile,
)


router = APIRouter(
    prefix="/profiles",
    tags=["profiles"],
)


@router.get("/{user_id}")
def profile(user_id: str):

    try:
        return get_profile(user_id)

    except Exception as error:

        print(repr(error))

        raise HTTPException(
            status_code=404,
            detail="Profile not found",
        ) from error


@router.patch("/{user_id}")
def update(
    user_id: str,
    request: ProfileUpdateRequest,
):

    updates = request.model_dump(
        exclude_none=True
    )

    if not updates:

        raise HTTPException(
            status_code=400,
            detail="No profile fields provided",
        )

    try:

        return update_profile(
            user_id,
            updates,
        )

    except Exception as error:

        print(repr(error))

        raise HTTPException(
            status_code=400,
            detail="Could not update profile",
        ) from error