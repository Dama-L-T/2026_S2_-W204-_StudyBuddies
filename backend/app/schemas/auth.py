from pydantic import BaseModel
from pydantic import BaseModel, EmailStr


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class VerifyResetOTPRequest(BaseModel):
    email: EmailStr
    otp: str


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    new_password: str

class LoginRequest(BaseModel):
    email: str
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class UserResponse(BaseModel):
    id: str
    email: str | None


class LoginResponseOrOTP(BaseModel):
    otp_required: bool
    message: str | None = None
    email: str | None = None

    user: UserResponse | None = None
    access_token: str | None = None
    refresh_token: str | None = None


class ResendLoginOTPRequest(BaseModel):
    email: str

    
class VerifyLoginOTPRequest(BaseModel):
    email: str
    otp: str


class RegisterRequest(BaseModel):
    email: str
    password: str


class LoginResponse(BaseModel):
    user: UserResponse
    access_token: str
    refresh_token: str


class RegisterResponse(BaseModel):
    message: str
    user: UserResponse


class CheckEmailRequest(BaseModel):
    email: str


class LoginOTPSettingRequest(BaseModel):
    enabled: bool


class LoginOTPSettingResponse(BaseModel):
    enabled: bool