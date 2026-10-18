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


def _get_conversation(client, conversation_id: str, user_id: str) -> dict[str, Any]:
    result = (
        client.table("chat_conversations")
        .select("id, participant_one_id, participant_two_id, created_at")
        .eq("id", conversation_id)
        .limit(1)
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Conversation not found")

    conversation = result.data[0]
    participants = {
        str(conversation["participant_one_id"]),
        str(conversation["participant_two_id"]),
    }
    if user_id not in participants:
        raise HTTPException(status_code=403, detail="You cannot access this conversation")
    return conversation


def _other_user_id(conversation: dict[str, Any], user_id: str) -> str:
    participant_one = str(conversation["participant_one_id"])
    participant_two = str(conversation["participant_two_id"])
    return participant_two if participant_one == user_id else participant_one


def _find_action_by_conversation(client, user_id: str, conversation_id: str):
    result = (
        client.table("chat_user_actions")
        .select("*")
        .eq("user_id", user_id)
        .eq("conversation_id", conversation_id)
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def _find_block_action(client, user_id: str, blocked_user_id: str):
    result = (
        client.table("chat_user_actions")
        .select("*")
        .eq("user_id", user_id)
        .eq("blocked_user_id", blocked_user_id)
        .eq("is_blocked", True)
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def _is_user_blocked(client, blocker_id: str, blocked_id: str) -> bool:
    result = (
        client.table("chat_user_actions")
        .select("id")
        .eq("user_id", blocker_id)
        .eq("blocked_user_id", blocked_id)
        .eq("is_blocked", True)
        .limit(1)
        .execute()
    )
    return bool(result.data)


def get_block_status(conversation_id: str, user_id: str) -> dict:
    client = _client()
    conversation = _get_conversation(client, conversation_id, user_id)
    other_id = _other_user_id(conversation, user_id)

    blocked_by_me = _is_user_blocked(client, user_id, other_id)
    has_blocked_me = _is_user_blocked(client, other_id, user_id)

    return {
        "is_blocked_by_me": blocked_by_me,
        "has_blocked_me": has_blocked_me,
        "is_blocked": blocked_by_me or has_blocked_me,
    }


def block_user(conversation_id: str, user_id: str) -> dict:
    client = _client()
    conversation = _get_conversation(client, conversation_id, user_id)
    other_id = _other_user_id(conversation, user_id)

    action = _find_action_by_conversation(client, user_id, conversation_id)

    if action:
        if action.get("is_blocked"):
            return {"message": "User is already blocked"}

        updated = (
            client.table("chat_user_actions")
            .update({
                "blocked_user_id": other_id,
                "is_blocked": True,
            })
            .eq("id", action["id"])
            .execute()
        )
        if not updated.data:
            raise HTTPException(status_code=500, detail="Failed to block user")
        return {"message": "User blocked successfully"}

    existing_block = _find_block_action(client, user_id, other_id)
    if existing_block:
        return {"message": "User is already blocked"}

    result = (
        client.table("chat_user_actions")
        .insert({
            "user_id": user_id,
            "blocked_user_id": other_id,
            "conversation_id": None,
            "is_blocked": True,
            "is_hidden": False,
        })
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to block user")
    return {"message": "User blocked successfully"}


def unblock_user(conversation_id: str, user_id: str) -> dict:
    client = _client()
    conversation = _get_conversation(client, conversation_id, user_id)
    other_id = _other_user_id(conversation, user_id)

    action = _find_block_action(client, user_id, other_id)
    if not action:
        return {"message": "User is not blocked"}

    if action.get("is_hidden"):
        result = (
            client.table("chat_user_actions")
            .update({
                "is_blocked": False,
                "blocked_user_id": None,
            })
            .eq("id", action["id"])
            .execute()
        )
    else:
        result = (
            client.table("chat_user_actions")
            .delete()
            .eq("id", action["id"])
            .execute()
        )

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to unblock user")
    return {"message": "User unblocked successfully"}


def hide_conversation(conversation_id: str, user_id: str) -> dict:
    client = _client()
    conversation = _get_conversation(client, conversation_id, user_id)
    other_id = _other_user_id(conversation, user_id)

    action = _find_action_by_conversation(client, user_id, conversation_id)
    if action:
        if action.get("is_hidden"):
            return {"message": "Conversation is already hidden"}

        result = (
            client.table("chat_user_actions")
            .update({"is_hidden": True})
            .eq("id", action["id"])
            .execute()
        )
        if not result.data:
            raise HTTPException(status_code=500, detail="Failed to hide conversation")
        return {"message": "Conversation hidden successfully"}

    existing_block = _find_block_action(client, user_id, other_id)
    if existing_block:
        result = (
            client.table("chat_user_actions")
            .update({
                "is_hidden": True,
                "conversation_id": conversation_id,
            })
            .eq("id", existing_block["id"])
            .execute()
        )
        if not result.data:
            raise HTTPException(status_code=500, detail="Failed to hide conversation")
        return {"message": "Conversation hidden successfully"}

    result = (
        client.table("chat_user_actions")
        .insert({
            "user_id": user_id,
            "blocked_user_id": None,
            "conversation_id": conversation_id,
            "is_blocked": False,
            "is_hidden": True,
        })
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to hide conversation")
    return {"message": "Conversation hidden successfully"}


def unhide_conversation(conversation_id: str, user_id: str) -> dict:
    client = _client()
    _get_conversation(client, conversation_id, user_id)

    action = _find_action_by_conversation(client, user_id, conversation_id)
    if not action or not action.get("is_hidden"):
        return {"message": "Conversation is not hidden"}

    if action.get("is_blocked"):
        result = (
            client.table("chat_user_actions")
            .update({
                "is_hidden": False,
                "conversation_id": None,
            })
            .eq("id", action["id"])
            .execute()
        )
    else:
        result = (
            client.table("chat_user_actions")
            .delete()
            .eq("id", action["id"])
            .execute()
        )

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to unhide conversation")
    return {"message": "Conversation unhidden successfully"}


def list_conversations(user_id: str) -> list[dict]:
    client = _client()
    result = (
        client.table("chat_conversations")
        .select("id, participant_one_id, participant_two_id, created_at")
        .or_(f"participant_one_id.eq.{user_id},participant_two_id.eq.{user_id}")
        .execute()
    )

    conversations = []
    for conversation in result.data or []:
        conversation_id = str(conversation["id"])
        other_id = _other_user_id(conversation, user_id)

        hidden_result = (
            client.table("chat_user_actions")
            .select("id")
            .eq("user_id", user_id)
            .eq("conversation_id", conversation_id)
            .eq("is_hidden", True)
            .limit(1)
            .execute()
        )
        if hidden_result.data:
            continue

        latest_result = (
            client.table("chat_messages")
            .select("content, created_at")
            .eq("conversation_id", conversation_id)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        latest_message = latest_result.data[0] if latest_result.data else None

        unread_result = (
            client.table("chat_messages")
            .select("id")
            .eq("conversation_id", conversation_id)
            .neq("sender_id", user_id)
            .is_("read_at", "null")
            .execute()
        )

        blocked_by_me = _is_user_blocked(client, user_id, other_id)
        has_blocked_me = _is_user_blocked(client, other_id, user_id)

        conversations.append({
            "id": conversation_id,
            "student_name": _profile_name(client, other_id),
            "last_message": latest_message["content"] if latest_message else "",
            "last_message_at": latest_message["created_at"] if latest_message else None,
            "unread_count": len(unread_result.data or []),
            "is_blocked_by_me": blocked_by_me,
            "has_blocked_me": has_blocked_me,
            "is_blocked": blocked_by_me or has_blocked_me,
        })

    conversations.sort(
        key=lambda item: item["last_message_at"] or "",
        reverse=True,
    )
    return conversations


def list_messages(conversation_id: str, user_id: str) -> list[dict]:
    client = _client()
    _get_conversation(client, conversation_id, user_id)

    result = (
        client.table("chat_messages")
        .select("id, conversation_id, sender_id, content, created_at, read_at")
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


def mark_conversation_read(conversation_id: str, user_id: str) -> dict:
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


def send_message(conversation_id: str, user_id: str, content: str) -> dict:
    client = _client()
    conversation = _get_conversation(client, conversation_id, user_id)
    other_id = _other_user_id(conversation, user_id)

    if _is_user_blocked(client, user_id, other_id) or _is_user_blocked(client, other_id, user_id):
        raise HTTPException(
            status_code=403,
            detail="Messaging is unavailable because one of you has blocked the other",
        )

    content = content.strip()
    if not content:
        raise HTTPException(status_code=422, detail="Message cannot be empty")

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
        raise HTTPException(status_code=500, detail="Failed to send message")

    message = result.data[0]
    return {
        "id": str(message["id"]),
        "sender_name": _profile_name(client, user_id),
        "content": message["content"],
        "created_at": message["created_at"],
        "is_mine": True,
    }


def edit_message(conversation_id: str, message_id: str, user_id: str, content: str) -> dict:
    client = _client()
    _get_conversation(client, conversation_id, user_id)

    content = content.strip()
    if not content:
        raise HTTPException(status_code=422, detail="Message cannot be empty")
    if len(content) > 5000:
        raise HTTPException(status_code=422, detail="Message cannot exceed 5000 characters")

    result = (
        client.table("chat_messages")
        .select("id, conversation_id, sender_id, content, created_at")
        .eq("id", message_id)
        .eq("conversation_id", conversation_id)
        .limit(1)
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Message not found")

    message = result.data[0]
    if str(message["sender_id"]) != user_id:
        raise HTTPException(status_code=403, detail="You can only edit your own messages")

    updated_result = (
        client.table("chat_messages")
        .update({"content": content})
        .eq("id", message_id)
        .eq("conversation_id", conversation_id)
        .eq("sender_id", user_id)
        .execute()
    )
    if not updated_result.data:
        raise HTTPException(status_code=500, detail="Failed to update message")

    updated_message = updated_result.data[0]
    return {
        "id": str(updated_message["id"]),
        "sender_name": _profile_name(client, user_id),
        "content": updated_message["content"],
        "created_at": updated_message["created_at"],
        "is_mine": True,
    }


def delete_message(conversation_id: str, message_id: str, user_id: str) -> dict:
    client = _client()
    _get_conversation(client, conversation_id, user_id)

    result = (
        client.table("chat_messages")
        .select("id, conversation_id, sender_id")
        .eq("id", message_id)
        .eq("conversation_id", conversation_id)
        .limit(1)
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Message not found")

    message = result.data[0]
    if str(message["sender_id"]) != user_id:
        raise HTTPException(status_code=403, detail="You can only delete your own messages")

    deleted_result = (
        client.table("chat_messages")
        .delete()
        .eq("id", message_id)
        .eq("conversation_id", conversation_id)
        .eq("sender_id", user_id)
        .execute()
    )
    if not deleted_result.data:
        raise HTTPException(status_code=500, detail="Failed to delete message")

    return {"message": "Message deleted"}

def list_blocked_users(user_id: str) -> list[dict]:
    client = _client()
    result = (
        client.table("chat_user_actions")
        .select("blocked_user_id")
        .eq("user_id", user_id)
        .eq("is_blocked", True)
        .execute()
    )

    blocked_users = []
    for action in result.data or []:
        blocked_user_id = action.get("blocked_user_id")
        if not blocked_user_id:
            continue
        blocked_users.append({
            "blocked_user_id": str(blocked_user_id),
            "blocked_user_name": _profile_name(client, str(blocked_user_id)),
        })

    return blocked_users


def list_hidden_conversations(user_id: str) -> list[dict]:
    client = _client()
    result = (
        client.table("chat_user_actions")
        .select("conversation_id")
        .eq("user_id", user_id)
        .eq("is_hidden", True)
        .execute()
    )

    hidden_conversations = []
    for action in result.data or []:
        conversation_id = action.get("conversation_id")
        if not conversation_id:
            continue

        try:
            conversation = _get_conversation(
                client, str(conversation_id), user_id
            )
        except HTTPException:
            continue

        other_id = _other_user_id(conversation, user_id)
        hidden_conversations.append({
            "conversation_id": str(conversation_id),
            "other_user_name": _profile_name(client, other_id),
        })

    return hidden_conversations


def unblock_user_by_id(user_id: str, blocked_user_id: str) -> dict:
    client = _client()
    action = _find_block_action(client, user_id, blocked_user_id)

    if not action:
        return {"message": "User is not blocked"}

    if action.get("is_hidden"):
        result = (
            client.table("chat_user_actions")
            .update({
                "is_blocked": False,
                "blocked_user_id": None,
            })
            .eq("id", action["id"])
            .execute()
        )
    else:
        result = (
            client.table("chat_user_actions")
            .delete()
            .eq("id", action["id"])
            .execute()
        )

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to unblock user")

    return {"message": "User unblocked successfully"}