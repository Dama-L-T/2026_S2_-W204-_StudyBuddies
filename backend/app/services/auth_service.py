from app.schemas.auth import LoginResponse, UserResponse
from app.services.supabase_service import get_supabase_client


def login_with_password(
    email: str,
    password: str,
) -> LoginResponse:

    supabase = get_supabase_client()

    response = supabase.auth.sign_in_with_password(
        {
            "email": email,
            "password": password,
        }
    )

    if response.user is None or response.session is None:
        raise ValueError("Invalid email or password")

    return LoginResponse(
        user=UserResponse(
            id=response.user.id,
            email=response.user.email,
        ),
        access_token=response.session.access_token,
        refresh_token=response.session.refresh_token,
    )

from app.schemas.auth import (
    LoginResponse,
    RegisterResponse,
    UserResponse,
)

from app.services.supabase_service import get_supabase_client


def login_with_password(
    email: str,
    password: str,
) -> LoginResponse:

    supabase = get_supabase_client()

    response = supabase.auth.sign_in_with_password(
        {
            "email": email,
            "password": password,
        }
    )

    if response.user is None or response.session is None:
        raise ValueError("Invalid email or password")

    return LoginResponse(
        user=UserResponse(
            id=response.user.id,
            email=response.user.email,
        ),
        access_token=response.session.access_token,
        refresh_token=response.session.refresh_token,
    )


def signup_with_email(
    email: str,
    password: str,
    name: str | None = None,
) -> RegisterResponse:

    supabase = get_supabase_client()

    response = supabase.auth.sign_up(
        {
            "email": email,
            "password": password,
        }
    )

    if response.user is None:
        raise ValueError("Could not create user")

    return RegisterResponse(
        message=(
            "Account created successfully. "
            "Please verify your email, then log in."
        ),
        user=UserResponse(
            id=response.user.id,
            email=response.user.email,
        ),
    )