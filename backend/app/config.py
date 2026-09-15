from dataclasses import dataclass
from functools import lru_cache
from os import getenv
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env")


@dataclass(frozen=True)
class Settings:
    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str
    assignment_table: str
    event_table: str
    user_id_field: str
    schedule_mock_json: str
    environment: str


@lru_cache
def get_settings() -> Settings:
    return Settings(
        supabase_url=getenv("SUPABASE_URL", ""),
        supabase_anon_key=getenv("SUPABASE_ANON_KEY", ""),
        supabase_service_role_key=getenv("SUPABASE_SERVICE_ROLE_KEY", ""),
        assignment_table=getenv("ASSIGNMENT_TABLE", "assignments"),
        event_table=getenv("EVENT_TABLE", "schedule"),
        user_id_field=getenv("USER_ID_FIELD", "user_id"),
        schedule_mock_json=getenv("SCHEDULE_MOCK_JSON", ""),
        environment=getenv("ENVIRONMENT", "development"),
    )
