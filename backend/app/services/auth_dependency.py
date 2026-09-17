from fastapi import Header, HTTPException

from app.services.supabase_service import get_supabase_client


def get_current_user_id(
    authorization: str | None = Header(default=None),
) -> str:

    if not authorization:
        raise HTTPException(
            status_code=401,
            detail="Missing authorization header.",
        )

    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail="Invalid authorization header.",
        )

    access_token = authorization[7:].strip()

    if not access_token:
        raise HTTPException(
            status_code=401,
            detail="Missing access token.",
        )

    try:
        supabase = get_supabase_client()

        response = supabase.auth.get_user(access_token)

        if response.user is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid or expired access token.",
            )

        return response.user.id

    except HTTPException:
        raise

    except Exception as error:
        print(
            "AUTHENTICATION ERROR:",
            repr(error),
        )

        raise HTTPException(
            status_code=401,
            detail="Invalid or expired access token.",
        ) from error