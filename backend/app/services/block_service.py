from fastapi import HTTPException

from app.services.supabase_service import get_supabase_client


def block_student(user_id: str, student_id: str) -> dict:
    """Block another student."""
    if user_id == student_id:
        raise HTTPException(
            status_code=400,
            detail="You cannot block yourself.",
        )

    supabase = get_supabase_client(use_service_role=True)

    target = (
        supabase.table("profiles")
        .select("user_id")
        .eq("user_id", student_id)
        .limit(1)
        .execute()
    )

    if not target.data:
        raise HTTPException(
            status_code=404,
            detail="Student not found.",
        )

    existing = (
        supabase.table("student_blocks")
        .select("id")
        .eq("blocker_id", user_id)
        .eq("blocked_id", student_id)
        .limit(1)
        .execute()
    )

    if existing.data:
        return {"message": "Student is already blocked."}

    supabase.table("student_blocks").insert({
        "blocker_id": user_id,
        "blocked_id": student_id,
    }).execute()

    return {"message": "Student blocked successfully."}


def unblock_student(user_id: str, student_id: str) -> dict:
    """Unblock a student previously blocked by the current user."""
    supabase = get_supabase_client(use_service_role=True)

    result = (
        supabase.table("student_blocks")
        .delete()
        .eq("blocker_id", user_id)
        .eq("blocked_id", student_id)
        .execute()
    )

    if not result.data:
        return {"message": "Student was not in your blocked list."}

    return {"message": "Student unblocked successfully."}


def list_blocked_students(user_id: str) -> list[dict]:
    """List students blocked by the current user."""
    supabase = get_supabase_client(use_service_role=True)

    blocks = (
        supabase.table("student_blocks")
        .select("blocked_id, created_at")
        .eq("blocker_id", user_id)
        .order("created_at", desc=True)
        .execute()
    )

    if not blocks.data:
        return []

    blocked_ids = [row["blocked_id"] for row in blocks.data]

    profiles = (
        supabase.table("profiles")
        .select("user_id, name, profile_image")
        .in_("user_id", blocked_ids)
        .execute()
    )

    profile_by_id = {
        profile["user_id"]: profile
        for profile in (profiles.data or [])
    }

    return [
        {
            **block,
            "profile": profile_by_id.get(block["blocked_id"]),
        }
        for block in blocks.data
    ]