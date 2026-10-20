from fastapi import APIRouter, Depends

from app.services.auth_dependency import get_current_user_id
from app.services.block_service import (
    block_student,
    unblock_student,
    list_blocked_students,
)

router = APIRouter(prefix="/blocks", tags=["Blocks"])


@router.post("/{student_id}")
def block_student_endpoint(
    student_id: str,
    user_id: str = Depends(get_current_user_id),
):
    return block_student(user_id, student_id)


@router.delete("/{student_id}")
def unblock_student_endpoint(
    student_id: str,
    user_id: str = Depends(get_current_user_id),
):
    return unblock_student(user_id, student_id)


@router.get("")
def list_blocked_students_endpoint(
    user_id: str = Depends(get_current_user_id),
):
    return list_blocked_students(user_id)