from app.services.supabase_service import get_supabase_client


def get_profile(user_id: str):

    supabase = get_supabase_client(
        use_service_role=True
    )

    response = (
        supabase
        .table("profiles")
        .select("*")
        .eq("id", user_id)
        .single()
        .execute()
    )

    if response.data is None:
        raise ValueError("Profile not found")

    return response.data


def update_profile(
    user_id: str,
    updates: dict,
):

    supabase = get_supabase_client(
        use_service_role=True
    )

    response = (
        supabase
        .table("profiles")
        .update(updates)
        .eq("id", user_id)
        .execute()
    )

    if not response.data:
        raise ValueError("Profile not found")

    return response.data[0]