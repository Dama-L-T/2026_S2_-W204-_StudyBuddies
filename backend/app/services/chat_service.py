
# backend/app/services/chat_service.py

from datetime import datetime, timezone
from typing import Any

from fastapi import HTTPException

from app.services.supabase_service import get_supabase_client


def _client():
    return get_supabase_client(use_service_role=True)


def _profile_name(client, user_id: str) -> str:
    result = (
        client.table("profiles")
        .select("name")
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )

    if result.data:
        return result.data[0].get("name") or "Student"

    return "Student"


def _get_conversation(
    client,
    conversation_id: str,
    user_id: str,
) -> dict[str, Any]:
    result = (
        client.table("chat_conversations")
        .select(
            "id, participant_one_id, participant_two_id, created_at"
        )
        .eq("id", conversation_id)
        .limit(1)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=404,
            detail="Conversation not found",
        )

    conversation = result.data[0]

    participants = {
        str(conversation["participant_one_id"]),
        str(conversation["participant_two_id"]),
    }

    if user_id not in participants:
        raise HTTPException(
            status_code=403,
            detail="You cannot access this conversation",
        )

    return conversation


def list_conversations(user_id: str) -> list[dict]:
    client = _client()

    result = (
        client.table("chat_conversations")
        .select(
            "id, participant_one_id, participant_two_id, created_at"
        )
        .or_(
            f"participant_one_id.eq.{user_id},"
            f"participant_two_id.eq.{user_id}"
        )
        .execute()
    )

    conversations = []

    for conversation in result.data or []:
        conversation_id = str(conversation["id"])

        participant_one = str(conversation["participant_one_id"])
        participant_two = str(conversation["participant_two_id"])

        other_user_id = (
            participant_two
            if participant_one == user_id
            else participant_one
        )

        latest_result = (
            client.table("chat_messages")
            .select("content, created_at")
            .eq("conversation_id", conversation_id)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )

        latest_message = (
            latest_result.data[0]
            if latest_result.data
            else None
        )

        unread_result = (
            client.table("chat_messages")
            .select("id")
            .eq("conversation_id", conversation_id)
            .neq("sender_id", user_id)
            .is_("read_at", "null")
            .execute()
        )

        conversations.append({
            "id": conversation_id,
            "student_name": _profile_name(
                client, other_user_id
            ),
            "last_message": (
                latest_message["content"]
                if latest_message
                else ""
            ),
            "last_message_at": (
                latest_message["created_at"]
                if latest_message
                else None
            ),
            "unread_count": len(unread_result.data or []),
        })

    # Most recently active conversations first.
    conversations.sort(
        key=lambda item: item["last_message_at"] or "",
        reverse=True,
    )

    return conversations


def list_messages(
    conversation_id: str,
    user_id: str,
) -> list[dict]:
    client = _client()

    _get_conversation(client, conversation_id, user_id)

    result = (
        client.table("chat_messages")
        .select(
            "id, conversation_id, sender_id, content, "
            "created_at, read_at"
        )
        .eq("conversation_id", conversation_id)
        .order("created_at", desc=False)
        .order("id", desc=False)
        .execute()
    )

    messages = []

    for message in result.data or []:
        sender_id = str(message["sender_id"])

        messages.append({
            "id": str(message["id"]),
            "sender_name": _profile_name(client, sender_id),
            "content": message["content"],
            "created_at": message["created_at"],
            "is_mine": sender_id == user_id,
        })

    return messages


def mark_conversation_read(
    conversation_id: str,
    user_id: str,
) -> dict:
    client = _client()

    _get_conversation(client, conversation_id, user_id)

    client.table("chat_messages").update({
        "read_at": datetime.now(timezone.utc).isoformat(),
    }).eq(
        "conversation_id", conversation_id
    ).neq(
        "sender_id", user_id
    ).is_(
        "read_at", "null"
    ).execute()

    return {"message": "Conversation marked as read"}


def send_message(
    conversation_id: str,
    user_id: str,
    content: str,
) -> dict:
    client = _client()

    # Verify that the authenticated student belongs to this conversation.
    _get_conversation(client, conversation_id, user_id)

    content = content.strip()
    if not content:
        raise HTTPException(
            status_code=422,
            detail="Message cannot be empty",
        )

    # Save the message using the authenticated student's ID.
    result = (
        client.table("chat_messages")
        .insert({
            "conversation_id": conversation_id,
            "sender_id": user_id,
            "content": content,
        })
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=500,
            detail="Failed to send message",
        )

    message = result.data[0]

    return {
        "id": str(message["id"]),
        "sender_name": _profile_name(client, user_id),
        "content": message["content"],
        "created_at": message["created_at"],
        "is_mine": True,
    }
