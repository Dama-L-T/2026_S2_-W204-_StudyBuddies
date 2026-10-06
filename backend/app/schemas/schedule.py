from pydantic import BaseModel, Field


class ScheduleItem(BaseModel):
    id: str
    item_type: str
    title: str
    date: str
    time: str
    location: str
    status: str = ""
    priority: str = ""


class ScheduleItemCreate(BaseModel):
    item_type: str
    title: str
    date: str
    time: str
    location: str = ""
    is_completed: bool = False


class ScheduleItemUpdate(BaseModel):
    title: str
    date: str
    time: str
    location: str = ""
    is_completed: bool = False


class ReminderCreate(BaseModel):
    minutes_before: int


class ReminderReplace(BaseModel):
    reminders: list[ReminderCreate] = Field(default_factory=list)


class Reminder(BaseModel):
    reminder_id: int
    user_id: str
    assignment_id: int | None = None
    event_id: int | None = None
    target_type: str | None = None
    target_id: str | None = None
    title: str | None = None
    reminder_type: str
    minutes_before: int
    remind_at: str
    created_at: str | None = None
    updated_at: str | None = None
