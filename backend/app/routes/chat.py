from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.services.chat_service import (
    list_conversations,
    list_messages,
    mark_conversation_read,
    send_message,
    edit_message,
    delete_message,
    block_user,
    unblock_user,
    hide_conversation,
    unhide_conversation,
    get_block_status,
)
from app.services.auth_dependency import get_current_user_id

router = APIRouter(prefix="/chat", tags=["Chat"])


class SendMessageRequest(BaseModel):
    content: str = Field(min_length=1, max_length=5000)


class EditMessageRequest(BaseModel):
    content: str = Field(min_length=1, max_length=5000)


@router.get("/conversations")
def get_conversations(user_id: str = Depends(get_current_user_id)):
    return list_conversations(str(user_id))


@router.get("/conversations/{conversation_id}/messages")
def get_conversation_messages(
    conversation_id: str,
    user_id: str = Depends(get_current_user_id),
):
    return list_messages(conversation_id=conversation_id, user_id=str(user_id))


@router.post("/conversations/{conversation_id}/messages", status_code=201)
def create_message(
    conversation_id: str,
    body: SendMessageRequest,
    user_id: str = Depends(get_current_user_id),
):
    content = body.content.strip()
    if not content:
        raise HTTPException(status_code=422, detail="Message cannot be empty")
    return send_message(
        conversation_id=conversation_id,
        user_id=str(user_id),
        content=content,
    )


@router.patch("/conversations/{conversation_id}/messages/{message_id}")
def update_message(
    conversation_id: str,
    message_id: str,
    body: EditMessageRequest,
    user_id: str = Depends(get_current_user_id),
):
    content = body.content.strip()
    if not content:
        raise HTTPException(status_code=422, detail="Message cannot be empty")
    return edit_message(
        conversation_id=conversation_id,
        message_id=message_id,
        user_id=str(user_id),
        content=content,
    )


@router.delete("/conversations/{conversation_id}/messages/{message_id}")
def remove_message(
    conversation_id: str,
    message_id: str,
    user_id: str = Depends(get_current_user_id),
):
    return delete_message(
        conversation_id=conversation_id,
        message_id=message_id,
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


@router.post("/conversations/{conversation_id}/block")
def create_block(
    conversation_id: str,
    user_id: str = Depends(get_current_user_id),
):
    return block_user(
        conversation_id=conversation_id,
        user_id=str(user_id),
    )


@router.delete("/conversations/{conversation_id}/block")
def remove_block(
    conversation_id: str,
    user_id: str = Depends(get_current_user_id),
):
    return unblock_user(
        conversation_id=conversation_id,
        user_id=str(user_id),
    )


@router.post("/conversations/{conversation_id}/hide")
def create_hidden_conversation(
    conversation_id: str,
    user_id: str = Depends(get_current_user_id),
):
    return hide_conversation(
        conversation_id=conversation_id,
        user_id=str(user_id),
    )


@router.delete("/conversations/{conversation_id}/hide")
def remove_hidden_conversation(
    conversation_id: str,
    user_id: str = Depends(get_current_user_id),
):
    return unhide_conversation(
        conversation_id=conversation_id,
        user_id=str(user_id),
    )


@router.get("/conversations/{conversation_id}/block-status")
def read_block_status(
    conversation_id: str,
    user_id: str = Depends(get_current_user_id),
):
    return get_block_status(
        conversation_id=conversation_id,
        user_id=str(user_id),
    )
