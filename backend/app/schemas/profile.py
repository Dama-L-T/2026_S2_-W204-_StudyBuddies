from pydantic import BaseModel


class ProfileUpdateRequest(BaseModel):
    name: str | None = None
    bio: str | None = None
    profile_picture_url: str | None = None
    cover_picture_url: str | None = None