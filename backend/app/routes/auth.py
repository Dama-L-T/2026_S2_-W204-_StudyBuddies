from fastapi import APIRouter, HTTPException

from app.schemas.auth import (
    LoginRequest,
    LoginResponse,
    RegisterRequest,
    RegisterResponse,
    CheckEmailRequest,
)

from app.services.auth_service import (
    login_with_password,
    signup_with_email,
    check_email_available,
)


router = APIRouter(
    prefix="/auth",
    tags=["authentication"],
)


@router.post(
    "/login",
    response_model=LoginResponse,
)
def login(request: LoginRequest):

    try:
        return login_with_password(
            request.email,
            request.password,
        )

    except Exception as error:

        print(repr(error))

        raise HTTPException(
            status_code=401,
            detail="Invalid email or password",
        ) from error


@router.post(
    "/register",
    response_model=RegisterResponse,
)
def register(request: RegisterRequest):

    try:
        return signup_with_email(
            request.email,
            request.password,
            request.name,
        )

    except Exception as error:

        print(repr(error))

        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error


@router.post("/check-email")
def check_email(request: CheckEmailRequest):
    try:
        available = check_email_available(request.email)

        if not available:
            raise HTTPException(
                status_code=409,
                detail="This email is already registered.",
            )

        return {
            "available": True,
            "message": "Email is available.",
        }

    except HTTPException:
        raise

    except Exception as error:
        print("CHECK EMAIL ERROR:", repr(error))

        raise HTTPException(
            status_code=500,
            detail=str(error),
        ) from error