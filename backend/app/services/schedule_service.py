import json
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any

from app.config import get_settings
from app.schemas.schedule import ScheduleItem, ScheduleItemCreate
from app.services.supabase_service import get_supabase_client


def list_schedule_items(access_token: str | None = None) -> list[ScheduleItem]:
    if get_settings().schedule_mock_json:
        return _list_mock_schedule_items()

    user_id = _require_user_id(access_token)
    return _list_upcoming_schedule_items(
        access_token=access_token,
        user_id=user_id,
    )


def create_schedule_item(
    payload: ScheduleItemCreate,
    access_token: str | None = None,
) -> ScheduleItem:
    if get_settings().schedule_mock_json:
        raise ValueError("Cannot create schedule items while mock schedule JSON is enabled")

    user_id = _require_user_id(access_token)
    item_type = payload.item_type.strip().lower()

    if item_type == "assignment":
        return _create_assignment(
            payload,
            access_token=access_token,
            user_id=user_id,
        )

    if item_type == "event":
        return _create_event(
            payload,
            access_token=access_token,
            user_id=user_id,
        )

    raise ValueError("item_type must be Assignment or Event")


def _list_mock_schedule_items() -> list[ScheduleItem]:
    mock_path = _mock_schedule_path()
    rows = json.loads(mock_path.read_text())

    if not isinstance(rows, list):
        raise ValueError("Mock schedule JSON must contain a list")

    return sorted(
        [ScheduleItem(**row) for row in rows],
        key=lambda item: (item.date, item.time),
    )


def _get_user_id_from_access_token(access_token: str) -> str | None:
    supabase = get_supabase_client()
    response = supabase.auth.get_user(access_token)

    if response.user is None:
        return None

    return response.user.id


def _require_user_id(access_token: str | None) -> str:
    if not access_token:
        raise PermissionError("Missing access token")

    user_id = _get_user_id_from_access_token(access_token)

    if user_id is None:
        raise PermissionError("Invalid access token")

    return user_id


def _list_upcoming_schedule_items(
    access_token: str,
    user_id: str,
) -> list[ScheduleItem]:
    settings = get_settings()
    supabase = get_supabase_client()
    supabase.postgrest.auth(access_token)
    today = date.today().isoformat()

    assignments_query = (
        supabase.table(settings.assignment_table)
        .select("*")
        .gte("due_date", today)
        .eq(settings.user_id_field, user_id)
        .order("due_date")
    )
    events_query = (
        supabase.table(settings.event_table)
        .select("*")
        .gte("start_time", f"{today}T00:00:00")
        .eq(settings.user_id_field, user_id)
        .order("start_time")
    )

    assignment_rows = assignments_query.execute().data or []
    event_rows = events_query.execute().data or []

    items = [
        *[_assignment_from_row(row) for row in assignment_rows],
        *[_event_from_row(row) for row in event_rows],
    ]

    return sorted(items, key=lambda item: (item.date, item.time))


def _create_assignment(
    payload: ScheduleItemCreate,
    access_token: str,
    user_id: str,
) -> ScheduleItem:
    settings = get_settings()
    supabase = get_supabase_client()
    supabase.postgrest.auth(access_token)
    due_date = _compose_datetime(payload.date, payload.time)

    row = {
        settings.user_id_field: user_id,
        "title": payload.title.strip(),
        "due_date": due_date.isoformat(),
        "priority": _assignment_priority(due_date),
        "status": "pending",
    }

    rows = (
        supabase.table(settings.assignment_table)
        .insert(row)
        .execute()
        .data
        or []
    )

    return _assignment_from_row(rows[0] if rows else row)


def _create_event(
    payload: ScheduleItemCreate,
    access_token: str,
    user_id: str,
) -> ScheduleItem:
    settings = get_settings()
    supabase = get_supabase_client()
    supabase.postgrest.auth(access_token)
    start_time = _compose_datetime(payload.date, payload.time)
    end_time = start_time + timedelta(hours=1)

    row = {
        settings.user_id_field: user_id,
        "title": payload.title.strip(),
        "location": payload.location.strip() or None,
        "start_time": start_time.isoformat(),
        "end_time": end_time.isoformat(),
        "event_type": "Study session",
    }

    rows = (
        supabase.table(settings.event_table)
        .insert(row)
        .execute()
        .data
        or []
    )

    return _event_from_row(rows[0] if rows else row)


def _assignment_from_row(row: dict[str, Any]) -> ScheduleItem:
    return ScheduleItem(
        id=str(row.get("assignment_id") or row.get("id") or ""),
        item_type="Assignment",
        title=str(row.get("title") or "Untitled assignment"),
        date=_date_part(row.get("due_date")),
        time=_time_part(row.get("due_date")) or "Due date",
        location="Not applicable",
    )


def _event_from_row(row: dict[str, Any]) -> ScheduleItem:
    return ScheduleItem(
        id=str(row.get("event_id") or row.get("id") or ""),
        item_type="Event",
        title=str(row.get("title") or "Untitled event"),
        date=_date_part(row.get("start_time")),
        time=_event_time(row),
        location=str(row.get("location") or row.get("description") or "Location TBC"),
    )


def _event_time(row: dict[str, Any]) -> str:
    start_time = _time_part(row.get("start_time"))
    end_time = _time_part(row.get("end_time"))

    if start_time and end_time:
        return f"{start_time} - {end_time}"

    return start_time or "Time TBC"


def _assignment_priority(due_date: datetime) -> str:
    time_until_due = due_date - datetime.now(due_date.tzinfo)

    if time_until_due <= timedelta(days=1):
        return "high"

    if time_until_due <= timedelta(days=7):
        return "medium"

    return "low"


def _date_part(value: Any) -> str:
    parsed = _parse_datetime(value)

    if parsed is None:
        return str(value or "")

    return parsed.date().isoformat()


def _time_part(value: Any) -> str:
    parsed = _parse_datetime(value)

    if parsed is None:
        return ""

    return parsed.strftime("%H:%M")


def _parse_datetime(value: Any) -> datetime | None:
    if not value:
        return None

    if isinstance(value, datetime):
        return value

    if isinstance(value, date):
        return datetime.combine(value, datetime.min.time())

    text = str(value).replace("Z", "+00:00")

    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def _compose_datetime(date_value: str, time_value: str) -> datetime:
    date_text = date_value.strip()
    time_text = time_value.strip()

    if not date_text:
        raise ValueError("date is required")

    if not time_text:
        raise ValueError("time is required")

    try:
        return datetime.fromisoformat(f"{date_text}T{time_text}")
    except ValueError as error:
        raise ValueError("date and time must be valid ISO values") from error


def _mock_schedule_path() -> Path:
    mock_json = get_settings().schedule_mock_json
    path = Path(mock_json)

    if not path.is_absolute():
        path = Path(__file__).resolve().parents[2] / path

    return path