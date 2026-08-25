from fastapi import APIRouter

from app.models.study_buddy import StudyBuddy
from app.services.study_buddy_service import list_study_buddies

router = APIRouter(prefix="/study-buddies", tags=["study buddies"])


@router.get("", response_model=list[StudyBuddy])
def get_study_buddies() -> list[StudyBuddy]:
    return list_study_buddies()
