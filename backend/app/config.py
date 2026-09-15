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
    schedule_mock_json: str
    environment: str

    brevo_smtp_host: str
    brevo_smtp_port: int
    brevo_smtp_user: str
    brevo_smtp_password: str
    brevo_sender_email: str
    brevo_sender_name: str

    otp_expiry_minutes: int
    otp_resend_seconds: int
    otp_max_attempts: int

@lru_cache
def get_settings() -> Settings:
    return Settings(
        supabase_url=getenv("SUPABASE_URL", ""),
        supabase_anon_key=getenv("SUPABASE_ANON_KEY", ""),
        supabase_service_role_key=getenv("SUPABASE_SERVICE_ROLE_KEY", ""),
        assignment_table=getenv("ASSIGNMENT_TABLE", "Assignment"),
        event_table=getenv("EVENT_TABLE", "Event"),
        schedule_mock_json=getenv("SCHEDULE_MOCK_JSON", ""),
        environment=getenv("ENVIRONMENT", "development"),
        brevo_smtp_host=getenv("BREVO_SMTP_HOST", "smtp-relay.brevo.com"),
        brevo_smtp_port=int(getenv("BREVO_SMTP_PORT", "587")),
        brevo_smtp_user=getenv("BREVO_SMTP_USER", ""),
        brevo_smtp_password=getenv("BREVO_SMTP_PASSWORD", ""),
        brevo_sender_email=getenv("BREVO_SENDER_EMAIL", ""),
        brevo_sender_name=getenv("BREVO_SENDER_NAME", "Study Buddies"),
        otp_expiry_minutes=int(getenv("OTP_EXPIRY_MINUTES", "10")),
        otp_resend_seconds=int(getenv("OTP_RESEND_SECONDS", "60")),
        otp_max_attempts=int(getenv("OTP_MAX_ATTEMPTS", "5")),
    )
