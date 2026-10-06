import json
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any

from app.config import get_settings
from app.schemas.schedule import (
    Reminder,
    ReminderReplace,
    ScheduleItem,
    ScheduleItemCreate,
    ScheduleItemUpdate,
)
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


def update_schedule_item(
    item_type: str,
    item_id: int,
    payload: ScheduleItemUpdate,
    access_token: str | None = None,
) -> ScheduleItem:
    if get_settings().schedule_mock_json:
        raise ValueError("Cannot update schedule items while mock schedule JSON is enabled")

    user_id = _require_user_id(access_token)
    normalized_type = item_type.strip().lower()

    if normalized_type == "assignment":
        return _update_assignment(
            item_id,
            payload,
            access_token=access_token,
            user_id=user_id,
        )

    if normalized_type == "event":
        return _update_event(
            item_id,
            payload,
            access_token=access_token,
            user_id=user_id,
        )

    raise ValueError("item_type must be Assignment or Event")


def delete_schedule_item(
    item_type: str,
    item_id: int,
    access_token: str | None = None,
) -> None:
    if get_settings().schedule_mock_json:
        raise ValueError("Cannot delete schedule items while mock schedule JSON is enabled")

    user_id = _require_user_id(access_token)
    normalized_type = item_type.strip().lower()

    if normalized_type == "assignment":
        _delete_item(
            table=get_settings().assignment_table,
            id_field="assignment_id",
            item_id=item_id,
            access_token=access_token,
            user_id=user_id,
        )
        return

    if normalized_type == "event":
        _delete_item(
            table=get_settings().event_table,
            id_field="event_id",
            item_id=item_id,
            access_token=access_token,
            user_id=user_id,
        )
        return

    raise ValueError("item_type must be Assignment or Event")


def list_reminders(
    item_type: str,
    item_id: int,
    access_token: str | None = None,
) -> list[Reminder]:
    if get_settings().schedule_mock_json:
        raise ValueError("Cannot load reminders while mock schedule JSON is enabled")

    user_id = _require_user_id(access_token)
    normalized_type = _normalize_item_type(item_type)
    item_datetime = _schedule_item_datetime(
        normalized_type,
        item_id,
        access_token=access_token,
        user_id=user_id,
    )

    if item_datetime is None:
        raise LookupError("Schedule item not found")

    return _list_reminders_for_item(
        normalized_type,
        item_id,
        access_token=access_token,
        user_id=user_id,
    )


def replace_reminders(
    item_type: str,
    item_id: int,
    payload: ReminderReplace,
    access_token: str | None = None,
) -> list[Reminder]:
    if get_settings().schedule_mock_json:
        raise ValueError("Cannot save reminders while mock schedule JSON is enabled")

    user_id = _require_user_id(access_token)
    normalized_type = _normalize_item_type(item_type)
    item_datetime = _schedule_item_datetime(
        normalized_type,
        item_id,
        access_token=access_token,
        user_id=user_id,
    )

    if item_datetime is None:
        raise LookupError("Schedule item not found")

    minutes_before_values = _normalized_reminder_minutes(payload)
    supabase = get_supabase_client()
    supabase.postgrest.auth(access_token)

    id_field = _reminder_item_id_field(normalized_type)

    (
        supabase.table("reminders")
        .delete()
        .eq("user_id", user_id)
        .eq(id_field, item_id)
        .execute()
    )

    if not minutes_before_values:
        return []

    rows = [
        _reminder_insert_row(
            item_type=normalized_type,
            item_id=item_id,
            user_id=user_id,
            minutes_before=minutes_before,
            item_datetime=item_datetime,
        )
        for minutes_before in minutes_before_values
    ]

    saved_rows = supabase.table("reminders").insert(rows).execute().data or []
    return [_reminder_from_row(row) for row in saved_rows]


def list_upcoming_reminders(access_token: str | None = None) -> list[Reminder]:
    if get_settings().schedule_mock_json:
        raise ValueError("Cannot load reminders while mock schedule JSON is enabled")

    user_id = _require_user_id(access_token)
    supabase = get_supabase_client()
    supabase.postgrest.auth(access_token)

    rows = (
        supabase.table("reminders")
        .select("*")
        .eq("user_id", user_id)
        .gte("remind_at", datetime.now().isoformat())
        .order("remind_at")
        .execute()
        .data
        or []
    )

    return [
        _reminder_with_target_from_row(
            row,
            access_token=access_token,
            user_id=user_id,
        )
        for row in rows
    ]


def _normalize_item_type(item_type: str) -> str:
    normalized_type = item_type.strip().lower()

    if normalized_type not in {"assignment", "event"}:
        raise ValueError("item_type must be Assignment or Event")

    return normalized_type


def _reminder_item_id_field(item_type: str) -> str:
    if item_type == "assignment":
        return "assignment_id"

    return "event_id"


def _normalized_reminder_minutes(payload: ReminderReplace) -> list[int]:
    if any(reminder.minutes_before < 0 for reminder in payload.reminders):
        raise ValueError("minutes_before must be zero or greater")

    values = {reminder.minutes_before for reminder in payload.reminders}

    return sorted(values, reverse=True)


def _reminder_type(minutes_before: int) -> str:
    if minutes_before == 10080:
        return "one_week"

    if minutes_before == 4320:
        return "three_days"

    if minutes_before == 1440:
        return "one_day"

    return "custom"


def _reminder_insert_row(
    item_type: str,
    item_id: int,
    user_id: str,
    minutes_before: int,
    item_datetime: datetime,
) -> dict[str, Any]:
    remind_at = item_datetime - timedelta(minutes=minutes_before)
    row: dict[str, Any] = {
        "user_id": user_id,
        "reminder_type": _reminder_type(minutes_before),
        "minutes_before": minutes_before,
        "remind_at": remind_at.isoformat(),
        "updated_at": datetime.now().isoformat(),
    }

    if item_type == "assignment":
        row["assignment_id"] = item_id
    else:
        row["event_id"] = item_id

    return row


def _list_reminders_for_item(
    item_type: str,
    item_id: int,
    access_token: str,
    user_id: str,
) -> list[Reminder]:
    supabase = get_supabase_client()
    supabase.postgrest.auth(access_token)
    id_field = _reminder_item_id_field(item_type)

    rows = (
        supabase.table("reminders")
        .select("*")
        .eq("user_id", user_id)
        .eq(id_field, item_id)
        .order("minutes_before", desc=True)
        .execute()
        .data
        or []
    )

    return [_reminder_from_row(row) for row in rows]


def _schedule_item_datetime(
    item_type: str,
    item_id: int,
    access_token: str,
    user_id: str,
) -> datetime | None:
    settings = get_settings()
    supabase = get_supabase_client()
    supabase.postgrest.auth(access_token)

    if item_type == "assignment":
        rows = (
            supabase.table(settings.assignment_table)
            .select("assignment_id,due_date")
            .eq("assignment_id", item_id)
            .eq(settings.user_id_field, user_id)
            .execute()
            .data
            or []
        )

        return _parse_datetime(rows[0].get("due_date")) if rows else None

    rows = (
        supabase.table(settings.event_table)
        .select("event_id,start_time")
        .eq("event_id", item_id)
        .eq(settings.user_id_field, user_id)
        .execute()
        .data
        or []
    )

    return _parse_datetime(rows[0].get("start_time")) if rows else None


def _reminder_from_row(row: dict[str, Any]) -> Reminder:
    return Reminder(
        reminder_id=int(row.get("reminder_id") or 0),
        user_id=str(row.get("user_id") or ""),
        assignment_id=row.get("assignment_id"),
        event_id=row.get("event_id"),
        target_type=row.get("target_type"),
        target_id=row.get("target_id"),
        title=row.get("title"),
        reminder_type=str(row.get("reminder_type") or "custom"),
        minutes_before=int(row.get("minutes_before") or 0),
        remind_at=str(row.get("remind_at") or ""),
        created_at=row.get("created_at"),
        updated_at=row.get("updated_at"),
    )


def _reminder_with_target_from_row(
    row: dict[str, Any],
    access_token: str,
    user_id: str,
) -> Reminder:
    assignment_id = row.get("assignment_id")
    event_id = row.get("event_id")

    if assignment_id is not None:
        target_row = _schedule_item_row(
            "assignment",
            int(assignment_id),
            access_token=access_token,
            user_id=user_id,
        )
        row = {
            **row,
            "target_type": "assignment",
            "target_id": str(assignment_id),
            "title": target_row.get("title") if target_row else None,
        }
        return _reminder_from_row(row)

    if event_id is not None:
        target_row = _schedule_item_row(
            "event",
            int(event_id),
            access_token=access_token,
            user_id=user_id,
        )
        row = {
            **row,
            "target_type": "event",
            "target_id": str(event_id),
            "title": target_row.get("title") if target_row else None,
        }
        return _reminder_from_row(row)

    return _reminder_from_row(row)


def _schedule_item_row(
    item_type: str,
    item_id: int,
    access_token: str,
    user_id: str,
) -> dict[str, Any] | None:
    settings = get_settings()
    supabase = get_supabase_client()
    supabase.postgrest.auth(access_token)

    if item_type == "assignment":
        rows = (
            supabase.table(settings.assignment_table)
            .select("assignment_id,title,due_date")
            .eq("assignment_id", item_id)
            .eq(settings.user_id_field, user_id)
            .execute()
            .data
            or []
        )

        return rows[0] if rows else None

    rows = (
        supabase.table(settings.event_table)
        .select("event_id,title,start_time")
        .eq("event_id", item_id)
        .eq(settings.user_id_field, user_id)
        .execute()
        .data
        or []
    )

    return rows[0] if rows else None


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

    try:
        response = supabase.auth.get_user(access_token)
    except Exception as error:
        raise PermissionError("Invalid or expired access token") from error

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
        "status": _assignment_status(payload.is_completed),
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


def _update_assignment(
    item_id: int,
    payload: ScheduleItemUpdate,
    access_token: str,
    user_id: str,
) -> ScheduleItem:
    settings = get_settings()
    supabase = get_supabase_client()
    supabase.postgrest.auth(access_token)
    due_date = _compose_datetime(payload.date, payload.time)

    row = {
        "title": payload.title.strip(),
        "due_date": due_date.isoformat(),
        "priority": _assignment_priority(due_date),
        "status": _assignment_status(payload.is_completed),
        "updated_at": datetime.now().isoformat(),
    }

    rows = (
        supabase.table(settings.assignment_table)
        .update(row)
        .eq("assignment_id", item_id)
        .eq(settings.user_id_field, user_id)
        .execute()
        .data
        or []
    )

    if not rows:
        raise LookupError("Assignment not found")

    return _assignment_from_row(rows[0])


def _update_event(
    item_id: int,
    payload: ScheduleItemUpdate,
    access_token: str,
    user_id: str,
) -> ScheduleItem:
    settings = get_settings()
    supabase = get_supabase_client()
    supabase.postgrest.auth(access_token)
    start_time = _compose_datetime(payload.date, payload.time)
    end_time = start_time + timedelta(hours=1)

    row = {
        "title": payload.title.strip(),
        "location": payload.location.strip() or None,
        "start_time": start_time.isoformat(),
        "end_time": end_time.isoformat(),
        "updated_at": datetime.now().isoformat(),
    }

    rows = (
        supabase.table(settings.event_table)
        .update(row)
        .eq("event_id", item_id)
        .eq(settings.user_id_field, user_id)
        .execute()
        .data
        or []
    )

    if not rows:
        raise LookupError("Event not found")

    return _event_from_row(rows[0])


def _delete_item(
    table: str,
    id_field: str,
    item_id: int,
    access_token: str,
    user_id: str,
) -> None:
    settings = get_settings()
    supabase = get_supabase_client()
    supabase.postgrest.auth(access_token)

    rows = (
        supabase.table(table)
        .delete()
        .eq(id_field, item_id)
        .eq(settings.user_id_field, user_id)
        .execute()
        .data
        or []
    )

    if not rows:
        raise LookupError("Schedule item not found")


def _assignment_from_row(row: dict[str, Any]) -> ScheduleItem:
    return ScheduleItem(
        id=str(row.get("assignment_id") or row.get("id") or ""),
        item_type="Assignment",
        title=str(row.get("title") or "Untitled assignment"),
        date=_date_part(row.get("due_date")),
        time=_time_part(row.get("due_date")) or "Due date",
        location="Not applicable",
        status=str(row.get("status") or "pending"),
        priority=str(row.get("priority") or ""),
    )


def _event_from_row(row: dict[str, Any]) -> ScheduleItem:
    return ScheduleItem(
        id=str(row.get("event_id") or row.get("id") or ""),
        item_type="Event",
        title=str(row.get("title") or "Untitled event"),
        date=_date_part(row.get("start_time")),
        time=_event_time(row),
        location=str(row.get("location") or row.get("description") or "Location TBC"),
        status="",
        priority="",
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


def _assignment_status(is_completed: bool) -> str:
    return "completed" if is_completed else "pending"


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
