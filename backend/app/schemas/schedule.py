from pydantic import BaseModel


class ScheduleItem(BaseModel):
    id: str
    item_type: str
    title: str
    date: str
    time: str
    location: str
