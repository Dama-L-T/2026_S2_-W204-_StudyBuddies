
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.services.chat_service import (
    list_conversations,
    list_messages,
    mark_conversation_read,
    send_message,
)

from app.services.auth_dependency import get_current_user_id


router = APIRouter(
    prefix="/chat",
    tags=["Chat"],
)


class SendMessageRequest(BaseModel):
    content: str = Field(min_length=1, max_length=5000)


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


@router.post(
    "/conversations/{conversation_id}/messages",
    status_code=201,
)
def create_message(
    conversation_id: str,
    body: SendMessageRequest,
    user_id: str = Depends(get_current_user_id),
):
    content = body.content.strip()

    if not content:
        raise HTTPException(
            status_code=422,
            detail="Message cannot be empty",
        )

    return send_message(
        conversation_id=conversation_id,
        user_id=str(user_id),
        content=content,
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
