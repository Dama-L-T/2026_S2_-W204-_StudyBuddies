from fastapi import Header, HTTPException
from app.services.supabase_service import get_supabase_client


def get_current_user(authorization: str = Header(...)):
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail="Missing or invalid authorization token",
        )

    access_token = authorization.replace("Bearer ", "", 1)

    try:
        supabase = get_supabase_client()

        response = supabase.auth.get_user(access_token)

        if response.user is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid access token",
            )

        return response.user

    except HTTPException:
        raise

    except Exception as error:
        print("AUTH ERROR:", repr(error))
        raise HTTPException(
            status_code=401,
            detail="Invalid access token",
        ) from error