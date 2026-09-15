from pydantic import BaseModel


class LoginRequest(BaseModel):
    email: str
    password: str


class LoginOTPRequiredResponse(BaseModel):
    otp_required: bool
    message: str
    email: str


class ResendLoginOTPRequest(BaseModel):
    email: str

    
class VerifyLoginOTPRequest(BaseModel):
    email: str
    otp: str


class RegisterRequest(BaseModel):
    email: str
    password: str


class UserResponse(BaseModel):
    id: str
    email: str | None


class LoginResponse(BaseModel):
    user: UserResponse
    access_token: str
    refresh_token: str


class RegisterResponse(BaseModel):
    message: str
    user: UserResponse


class CheckEmailRequest(BaseModel):
    email: str