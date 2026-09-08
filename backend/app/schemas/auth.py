from pydantic import BaseModel


class LoginRequest(BaseModel):
    email: str
    password: str


class RegisterRequest(BaseModel):
    email: str
    password: str
    name: str | None = None


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