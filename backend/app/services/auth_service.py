from app.schemas.auth import LoginResponse, UserResponse, RegisterResponse
from app.services.supabase_service import get_supabase_client
from app.services.otp_service import OTPService
from fastapi import BackgroundTasks

# Temporary storage for login sessions waiting for OTP verification.
# Key: email
# Value: Supabase access/refresh tokens + user information

_pending_logins: dict[str, dict] = {}
# Temporary storage for password reset sessions.
# Key: email
# Value: user_id + OTP verification status
_pending_password_resets: dict[str, dict] = {}

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

    user_id = response.user.id

    # Check whether this user requires login verification.
    otp_enabled = get_login_otp_setting(user_id)

    # ---------------------------------------------------------
    # OTP disabled
    # ---------------------------------------------------------

    if not otp_enabled:
        return {
            "otp_required": False,
            "user": {
                "id": response.user.id,
                "email": response.user.email,
            },
            "access_token": response.session.access_token,
            "refresh_token": response.session.refresh_token,
        }

    # ---------------------------------------------------------
    # OTP enabled
    # ---------------------------------------------------------

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
        user_id=user_id,
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


def refresh_access_token(refresh_token: str) -> LoginResponse:
    supabase = get_supabase_client()

    response = supabase.auth.refresh_session(refresh_token)

    if response.user is None or response.session is None:
        raise ValueError("Invalid refresh token")

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



def get_login_otp_setting(user_id: str) -> bool:
    supabase = get_supabase_client(use_service_role=True)

    response = (
        supabase
        .table("user_settings")
        .select("login_otp_enabled")
        .eq("user_id", user_id)
        .execute()
    )

    if not response or not response.data:
        return False

    return response.data[0]["login_otp_enabled"]


def update_login_otp_setting(
    user_id: str,
    enabled: bool,
) -> bool:

    supabase = get_supabase_client(
        use_service_role=True
    )

    response = (
        supabase
        .table("user_settings")
        .upsert({
            "user_id": user_id,
            "login_otp_enabled": enabled,
        })
        .execute()
    )

    if not response.data:
        raise ValueError(
            "Unable to update login verification setting."
        )

    return response.data[0]["login_otp_enabled"]


def request_password_reset(
    email: str,
    background_tasks: BackgroundTasks,
):
    email = email.strip().lower()

    supabase = get_supabase_client(
        use_service_role=True
    )

    # Find the user by email.
    response = supabase.auth.admin.list_users()

    users = response

    if hasattr(response, "users"):
        users = response.users

    user = None

    for existing_user in users:
        if (
            existing_user.email
            and existing_user.email.lower() == email
        ):
            user = existing_user
            break

    if user is None:
        # Don't reveal whether an email exists.
        return {
            "message": (
                "If an account exists for this email, "
                "a verification code has been sent."
            ),
            "email": email,
        }

    user_id = user.id

    # Store pending password reset.
    _pending_password_resets[email] = {
        "user_id": user_id,
        "email": email,
        "verified": False,
    }

    otp_service = OTPService()

    otp = otp_service.create_otp(
        email=email,
        purpose="reset_password",
        user_id=user_id,
    )

    background_tasks.add_task(
        otp_service.send_otp_email,
        email,
        otp,
        "reset_password",
    )

    return {
        "message": "A verification code has been sent to your email.",
        "email": email,
    }

def verify_reset_otp(
    email: str,
    otp: str,
):
    email = email.strip().lower()

    pending_reset = _pending_password_resets.get(email)

    if pending_reset is None:
        raise ValueError(
            "No password reset request found. "
            "Please request a new verification code."
        )

    otp_service = OTPService()

    otp_service.verify_otp(
        email=email,
        purpose="reset_password",
        otp=otp,
    )

    # OTP is correct.
    pending_reset["verified"] = True

    return {
        "message": "Verification code confirmed.",
        "email": email,
    }

def reset_password(
    email: str,
    new_password: str,
):
    email = email.strip().lower()

    pending_reset = _pending_password_resets.get(email)

    if pending_reset is None:
        raise ValueError(
            "No password reset request found."
        )

    if not pending_reset.get("verified"):
        raise ValueError(
            "Please verify the verification code first."
        )

    if len(new_password) < 8:
        raise ValueError(
            "Password must be at least 8 characters long."
        )

    supabase = get_supabase_client(
        use_service_role=True
    )

    user_id = pending_reset["user_id"]

    # Update the Supabase Auth password.
    supabase.auth.admin.update_user_by_id(
        user_id,
        {
            "password": new_password,
        },
    )

    # Remove the reset session so it cannot be reused.
    del _pending_password_resets[email]

    return {
        "message": "Password reset successfully.",
    }