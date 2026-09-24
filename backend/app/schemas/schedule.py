from pydantic import BaseModel


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
