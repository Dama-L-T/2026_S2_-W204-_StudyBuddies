import logging

from fastapi import APIRouter, HTTPException

from app.schemas.auth import (
    LoginRequest,
    LoginResponse,
    RefreshRequest,
    RegisterRequest,
    RegisterResponse,
    CheckEmailRequest,
)

from app.services.auth_service import (
    login_with_password,
    refresh_access_token,
    signup_with_email,
    check_email_available,
)


router = APIRouter(
    prefix="/auth",
    tags=["authentication"],
)
logger = logging.getLogger(__name__)


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
        logger.exception("Login failed")

        raise HTTPException(
            status_code=401,
            detail="Invalid email or password",
        ) from error


@router.post(
    "/refresh",
    response_model=LoginResponse,
)
def refresh(request: RefreshRequest):

    try:
        return refresh_access_token(request.refresh_token)

    except Exception as error:
        logger.exception("Token refresh failed")

        raise HTTPException(
            status_code=401,
            detail="Invalid refresh token",
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
        logger.exception("Registration failed")

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
        logger.exception("Email availability check failed")

        raise HTTPException(
            status_code=500,
            detail=str(error),
        ) from error
