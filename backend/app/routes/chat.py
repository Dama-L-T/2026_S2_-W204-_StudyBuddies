
# backend/app/routes/chat.py

from fastapi import APIRouter, Depends

from app.services.chat_service import (
    list_conversations,
    list_messages,
    mark_conversation_read,
)

# Use the same dependency import used by your existing
# authenticated routes. This assumes it is defined here.
from app.services.auth_dependency import get_current_user_id


router = APIRouter(
    prefix="/chat",
    tags=["Chat"],
)


@router.get("/conversations")
def get_conversations(
    user_id: str = Depends(get_current_user_id),
):
    return list_conversations(str(user_id))


@router.get("/conversations/{conversation_id}/messages")
def get_conversation_messages(
    conversation_id: str,
    user_id: str = Depends(get_current_user_id),
):
    return list_messages(
        conversation_id=conversation_id,
        user_id=str(user_id),
    )


@router.post("/conversations/{conversation_id}/read")
def read_conversation(
    conversation_id: str,
    user_id: str = Depends(get_current_user_id),
):
    return mark_conversation_read(
        conversation_id=conversation_id,
        user_id=str(user_id),
    )
