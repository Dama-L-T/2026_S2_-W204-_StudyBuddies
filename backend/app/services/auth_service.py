from app.schemas.auth import LoginResponse, UserResponse, RegisterResponse
from app.services.supabase_service import get_supabase_client
from app.services.otp_service import OTPService
from fastapi import BackgroundTasks

# Temporary storage for login sessions waiting for OTP verification.
# Key: email
# Value: Supabase access/refresh tokens + user information
_pending_logins: dict[str, dict] = {}


def login_with_password(
    email: str,
    password: str,
    background_tasks: BackgroundTasks,
):
    email = email.strip().lower()

    supabase = get_supabase_client()

    response = supabase.auth.sign_in_with_password(
        {
            "email": email,
            "password": password,
        }
    )

    if response.user is None or response.session is None:
        raise ValueError("Invalid email or password")

    _pending_logins[email] = {
        "user_id": response.user.id,
        "email": response.user.email,
        "access_token": response.session.access_token,
        "refresh_token": response.session.refresh_token,
    }

    otp_service = OTPService()

    otp = otp_service.create_otp(
        email=email,
        purpose="login",
        user_id=response.user.id,
    )

    background_tasks.add_task(
        otp_service.send_otp_email,
        email,
        otp,
        "login",
    )

    return {
        "otp_required": True,
        "message": "A verification code is being sent to your email.",
        "email": email,
    }


def resend_login_otp(
    email: str,
    background_tasks: BackgroundTasks,
):
    email = email.strip().lower()

    pending_login = _pending_logins.get(email)

    if pending_login is None:
        raise ValueError(
            "No pending login found. Please log in again."
        )

    otp_service = OTPService()

    otp = otp_service.resend_otp(
        email=email,
        purpose="login",
        user_id=pending_login["user_id"],
    )

    background_tasks.add_task(
        otp_service.send_otp_email,
        email,
        otp,
        "login",
    )

    return {
        "message": "A new verification code has been sent to your email.",
        "email": email,
    }


def verify_login_otp(
    email: str,
    otp: str,
) -> LoginResponse:

    email = email.strip().lower()

    # Check that this email has a pending login.
    pending_login = _pending_logins.get(email)

    if pending_login is None:
        raise ValueError(
            "No pending login found. Please log in again."
        )

    # Verify the OTP.
    otp_service = OTPService()

    otp_service.verify_otp(
        email=email,
        purpose="login",
        otp=otp,
    )

    # OTP is correct.
    login_response = LoginResponse(
        user=UserResponse(
            id=pending_login["user_id"],
            email=pending_login["email"],
        ),
        access_token=pending_login["access_token"],
        refresh_token=pending_login["refresh_token"],
    )

    # Remove the pending login so it cannot be reused.
    del _pending_logins[email]

    return login_response


def signup_with_email(
    email: str,
    password: str,
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
            "Account created successfully."
        ),
        user=UserResponse(
            id=response.user.id,
            email=response.user.email,
        ),
    )


def check_email_available(email: str) -> bool:
    supabase = get_supabase_client(use_service_role=True)

    response = supabase.auth.admin.list_users()

    users = response

    if hasattr(response, "users"):
        users = response.users

    for user in users:
        if user.email and user.email.lower() == email.lower():
            return False

    return True