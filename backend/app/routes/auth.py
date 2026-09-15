from fastapi import APIRouter, HTTPException, BackgroundTasks

from app.schemas.auth import (
    LoginRequest,
    LoginResponse,
    RegisterRequest,
    RegisterResponse,
    CheckEmailRequest,
    LoginOTPRequiredResponse,
    ResendLoginOTPRequest,
    VerifyLoginOTPRequest,
)

from app.services.auth_service import (
    login_with_password,
    signup_with_email,
    check_email_available,
    resend_login_otp,
    verify_login_otp,
)


router = APIRouter(
    prefix="/auth",
    tags=["authentication"],
)


# ---------------------------------------------------------
# Login
# ---------------------------------------------------------

@router.post(
    "/login",
    response_model=LoginOTPRequiredResponse,
)
def login(
    request: LoginRequest,
    background_tasks: BackgroundTasks,
):

    try:
        return login_with_password(
            request.email,
            request.password,
            background_tasks,
        )

    except Exception as error:
        import traceback

        print("LOGIN ERROR:", repr(error))
        traceback.print_exc()

        raise HTTPException(
            status_code=401,
            detail=str(error),
        ) from error

#---------------------------------------------------------
# Resend Login OTP
#---------------------------------------------------------
@router.post("/resend-login-otp")
def resend_login_otp_route(
    request: ResendLoginOTPRequest,
    background_tasks: BackgroundTasks,
):
    try:
        return resend_login_otp(
            request.email,
            background_tasks,
        )
    except Exception as error:
        print("RESEND LOGIN OTP ERROR:", repr(error))

        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error

    
# ---------------------------------------------------------
# Verify Login OTP
# ---------------------------------------------------------

@router.post(
    "/verify-login-otp",
    response_model=LoginResponse,
)
def verify_login_otp_endpoint(
    request: VerifyLoginOTPRequest,
):

    try:
        return verify_login_otp(
            request.email,
            request.otp,
        )

    except Exception as error:

        print("LOGIN OTP ERROR:", repr(error))

        raise HTTPException(
            status_code=401,
            detail=str(error),
        ) from error


# ---------------------------------------------------------
# Register
# ---------------------------------------------------------

@router.post(
    "/register",
    response_model=RegisterResponse,
)
def register(request: RegisterRequest):

    try:
        return signup_with_email(
            request.email,
            request.password,
        )

    except Exception as error:

        print("REGISTER ERROR:", repr(error))

        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error


# ---------------------------------------------------------
# Check Email
# ---------------------------------------------------------

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