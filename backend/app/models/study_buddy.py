from pydantic import BaseModel


class StudyBuddy(BaseModel):
    id: str
    name: str
    subject: str
