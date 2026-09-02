import json
from datetime import date, datetime
from pathlib import Path
from typing import Any

from app.config import get_settings
from app.schemas.schedule import ScheduleItem
from app.services.supabase_service import get_supabase_client


def list_schedule_items(access_token: str | None = None) -> list[ScheduleItem]:
    if get_settings().schedule_mock_json:
        return _list_mock_schedule_items()

    if not access_token:
        raise PermissionError("Missing access token")

    student_id = _get_student_id_from_access_token(access_token)

    if student_id is None:
        raise PermissionError("Invalid access token")

    return _list_upcoming_schedule_items(student_id=student_id)


def _list_mock_schedule_items() -> list[ScheduleItem]:
    mock_path = _mock_schedule_path()
    rows = json.loads(mock_path.read_text())

    if not isinstance(rows, list):
        raise ValueError("Mock schedule JSON must contain a list")

    return sorted(
        [ScheduleItem(**row) for row in rows],
        key=lambda item: (item.date, item.time),
    )


def _get_student_id_from_access_token(access_token: str) -> str | None:
    supabase = get_supabase_client()
    response = supabase.auth.get_user(access_token)

    if response.user is None:
        return None

    return response.user.id


def _list_upcoming_schedule_items(student_id: str) -> list[ScheduleItem]:
    settings = get_settings()
    supabase = get_supabase_client(use_service_role=True)
    today = date.today().isoformat()

    assignments_query = (
        supabase.table(settings.assignment_table)
        .select("*")
        .gte("dueDate", today)
        .order("dueDate")
    )
    events_query = (
        supabase.table(settings.event_table)
        .select("*")
        .gte("startTime", f"{today}T00:00:00")
        .order("startTime")
    )

    assignments_query = assignments_query.eq("studentId", student_id)
    events_query = events_query.eq("studentId", student_id)

    assignment_rows = assignments_query.execute().data or []
    event_rows = events_query.execute().data or []

    items = [
        *[_assignment_from_row(row) for row in assignment_rows],
        *[_event_from_row(row) for row in event_rows],
    ]

    return sorted(items, key=lambda item: (item.date, item.time))


def _assignment_from_row(row: dict[str, Any]) -> ScheduleItem:
    return ScheduleItem(
        id=str(row.get("assignmentId") or row.get("id") or ""),
        item_type="Assignment",
        title=str(row.get("title") or "Untitled assignment"),
        date=_date_part(row.get("dueDate")),
        time=_time_part(row.get("dueDate")) or "Due date",
        location="Not applicable",
    )


def _event_from_row(row: dict[str, Any]) -> ScheduleItem:
    return ScheduleItem(
        id=str(row.get("eventId") or row.get("id") or ""),
        item_type="Event",
        title=str(row.get("title") or "Untitled event"),
        date=_date_part(row.get("startTime")),
        time=_event_time(row),
        location=str(row.get("location") or "Location TBC"),
    )


def _event_time(row: dict[str, Any]) -> str:
    start_time = _time_part(row.get("startTime"))
    end_time = _time_part(row.get("endTime"))

    if start_time and end_time:
        return f"{start_time} - {end_time}"

    return start_time or "Time TBC"


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


def _mock_schedule_path() -> Path:
    mock_json = get_settings().schedule_mock_json
    path = Path(mock_json)

    if not path.is_absolute():
        path = Path(__file__).resolve().parents[2] / path

    return path
