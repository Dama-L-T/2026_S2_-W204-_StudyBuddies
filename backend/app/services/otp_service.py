import hashlib
import secrets
import smtplib
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage

from app.config import get_settings
from app.services.supabase_service import get_supabase_client


class OTPError(Exception):
    """Base exception for OTP-related errors."""


class OTPExpiredError(OTPError):
    """OTP has expired."""


class OTPInvalidError(OTPError):
    """OTP is incorrect."""


class OTPMaxAttemptsError(OTPError):
    """Too many incorrect OTP attempts."""


class OTPResendTooSoonError(OTPError):
    """OTP was requested too recently."""


class OTPService:

    PURPOSES = {
        "register",
        "login",
        "reset_password",
    }

    def __init__(self):
        self.settings = get_settings()
        self.supabase = get_supabase_client(
            use_service_role=True
        )

    def _parse_datetime(self, value) -> datetime:
        if isinstance(value, datetime):
            result = value
        else:
            value = str(value).strip()

            if value.endswith("Z"):
                value = value[:-1] + "+00:00"

            result = datetime.fromisoformat(value)

        if result.tzinfo is None:
            result = result.replace(tzinfo=timezone.utc)

        return result

    # ---------------------------------------------------------
    # Generate
    # ---------------------------------------------------------

    def _generate_otp(self) -> str:
        """
        Generate a cryptographically secure 6-digit OTP.
        """
        return f"{secrets.randbelow(1_000_000):06d}"

    # ---------------------------------------------------------
    # Hash
    # ---------------------------------------------------------

    def _hash_otp(self, otp: str) -> str:
        """
        Hash the OTP before storing it.
        """
        return hashlib.sha256(
            otp.encode("utf-8")
        ).hexdigest()

    # ---------------------------------------------------------
    # Send email
    # ---------------------------------------------------------

    def _send_email(
        self,
        email: str,
        otp: str,
        purpose: str,
    ) -> None:

        if purpose == "register":

            subject = (
                "Study Buddies - Verify your email"
            )

            message = (
                "Use the verification code below to "
                "verify your Study Buddies account."
            )

        elif purpose == "login":

            subject = (
                "Study Buddies - Login verification code"
            )

            message = (
                "Use the verification code below to "
                "complete your Study Buddies login."
            )

        elif purpose == "reset_password":

            subject = (
                "Study Buddies - Password reset code"
            )

            message = (
                "Use the verification code below to "
                "reset your Study Buddies password."
            )

        else:
            raise ValueError("Invalid OTP purpose")

        expires_minutes = (
            self.settings.otp_expiry_minutes
        )

        email_body = f"""
Hello,

{message}

Your verification code is:

{otp}

This code expires in {expires_minutes} minutes.

If you did not request this code, you can safely ignore this email.

Study Buddies
"""

        msg = EmailMessage()

        msg["Subject"] = subject

        msg["From"] = (
            f"{self.settings.brevo_sender_name} "
            f"<{self.settings.brevo_sender_email}>"
        )

        msg["To"] = email

        msg.set_content(email_body)

        try:

            with smtplib.SMTP(
                self.settings.brevo_smtp_host,
                self.settings.brevo_smtp_port,
                timeout=20,
            ) as server:

                server.starttls()

                server.login(
                    self.settings.brevo_smtp_user,
                    self.settings.brevo_smtp_password,
                )

                server.send_message(msg)

        except Exception as exc:

            raise OTPError(
                f"Failed to send OTP email: {exc}"
            ) from exc

    # ---------------------------------------------------------
    # Public email sending method
    # ---------------------------------------------------------

    def send_otp_email(
        self,
        email: str,
        otp: str,
        purpose: str,
    ) -> None:
        """
        Send an already-created OTP email.

        This method is separated from create_otp() so the
        email can be sent in the background.
        """

        self._send_email(
            email=email,
            otp=otp,
            purpose=purpose,
        )

    # ---------------------------------------------------------
    # Delete expired OTPs
    # ---------------------------------------------------------

    def _delete_expired_otps(
        self,
        email: str | None = None,
    ) -> None:
        """
        Remove expired OTP records.
        """

        now = datetime.now(
            timezone.utc
        ).isoformat()

        query = (
            self.supabase
            .table("otp_challenges")
            .delete()
            .lt("expires_at", now)
        )

        if email:
            query = query.eq(
                "email",
                email,
            )

        query.execute()

    # ---------------------------------------------------------
    # Create OTP
    # ---------------------------------------------------------

    def create_otp(
        self,
        email: str,
        purpose: str,
        user_id: str | None = None,
    ) -> str:
        """
        Generate and store an OTP.

        The OTP email is NOT sent here.

        Returns:
            The plain 6-digit OTP so it can be passed to
            the background email task.
        """

        if purpose not in self.PURPOSES:
            raise ValueError(
                "Invalid OTP purpose"
            )

        email = email.strip().lower()

        self._delete_expired_otps(email)

        # -----------------------------------------------------
        # Find the most recent OTP for this email/purpose.
        # -----------------------------------------------------

        response = (
            self.supabase
            .table("otp_challenges")
            .select(
                "id, created_at"
            )
            .eq(
                "email",
                email,
            )
            .eq(
                "purpose",
                purpose,
            )
            .order(
                "created_at",
                desc=True,
            )
            .limit(1)
            .execute()
        )

        if response.data:

            latest = response.data[0]

            created_at = self._parse_datetime(latest["created_at"])

            now = datetime.now(
                timezone.utc
            )

            elapsed = (
                now - created_at
            ).total_seconds()

            if (
                elapsed
                < self.settings.otp_resend_seconds
            ):

                remaining = int(
                    self.settings.otp_resend_seconds
                    - elapsed
                )

                raise OTPResendTooSoonError(
                    f"Please wait {remaining} seconds "
                    "before requesting another code."
                )

            # -------------------------------------------------
            # Invalidate previous OTP.
            # -------------------------------------------------

            (
                self.supabase
                .table("otp_challenges")
                .delete()
                .eq(
                    "email",
                    email,
                )
                .eq(
                    "purpose",
                    purpose,
                )
                .execute()
            )

        # -----------------------------------------------------
        # Generate new OTP.
        # -----------------------------------------------------

        otp = self._generate_otp()

        otp_hash = self._hash_otp(
            otp
        )

        now = datetime.now(
            timezone.utc
        )

        expires_at = (
            now
            + timedelta(
                minutes=(
                    self.settings.otp_expiry_minutes
                )
            )
        )

        # -----------------------------------------------------
        # Store only the hash.
        # -----------------------------------------------------

        (
            self.supabase
            .table("otp_challenges")
            .insert(
                {
                    "user_id": user_id,
                    "email": email,
                    "purpose": purpose,
                    "otp_hash": otp_hash,
                    "expires_at": (
                        expires_at.isoformat()
                    ),
                    "attempts": 0,
                }
            )
            .execute()
        )

        # -----------------------------------------------------
        # IMPORTANT:
        # Do NOT send the email here.
        #
        # The caller will send it using BackgroundTasks.
        # -----------------------------------------------------

        return otp

    # ---------------------------------------------------------
    # Verify OTP
    # ---------------------------------------------------------

    def verify_otp(
        self,
        email: str,
        purpose: str,
        otp: str,
    ) -> bool:

        if purpose not in self.PURPOSES:
            raise ValueError(
                "Invalid OTP purpose"
            )

        email = email.strip().lower()

        otp = otp.strip()

        # -----------------------------------------------------
        # Validate OTP format.
        # -----------------------------------------------------

        if (
            not otp.isdigit()
            or len(otp) != 6
        ):

            raise OTPInvalidError(
                "Invalid verification code."
            )

        self._delete_expired_otps(email)

        # -----------------------------------------------------
        # Find latest OTP.
        # -----------------------------------------------------

        response = (
            self.supabase
            .table("otp_challenges")
            .select("*")
            .eq(
                "email",
                email,
            )
            .eq(
                "purpose",
                purpose,
            )
            .order(
                "created_at",
                desc=True,
            )
            .limit(1)
            .execute()
        )

        if not response.data:

            raise OTPInvalidError(
                "Invalid or expired verification code."
            )

        challenge = response.data[0]

        # -----------------------------------------------------
        # Check expiration.
        # -----------------------------------------------------

        expires_at = self._parse_datetime(challenge["expires_at"])

        now = datetime.now(
            timezone.utc
        )

        if now >= expires_at:

            (
                self.supabase
                .table("otp_challenges")
                .delete()
                .eq(
                    "id",
                    challenge["id"],
                )
                .execute()
            )

            raise OTPExpiredError(
                "This verification code has expired."
            )

        # -----------------------------------------------------
        # Check attempt limit.
        # -----------------------------------------------------

        attempts = challenge["attempts"]

        if (
            attempts
            >= self.settings.otp_max_attempts
        ):

            (
                self.supabase
                .table("otp_challenges")
                .delete()
                .eq(
                    "id",
                    challenge["id"],
                )
                .execute()
            )

            raise OTPMaxAttemptsError(
                "Too many incorrect attempts. "
                "Please request a new code."
            )

        # -----------------------------------------------------
        # Hash supplied OTP.
        # -----------------------------------------------------

        supplied_hash = self._hash_otp(
            otp
        )

        # -----------------------------------------------------
        # Compare hashes.
        # -----------------------------------------------------

        if not secrets.compare_digest(
            supplied_hash,
            challenge["otp_hash"],
        ):

            (
                self.supabase
                .table("otp_challenges")
                .update(
                    {
                        "attempts": attempts + 1,
                    }
                )
                .eq(
                    "id",
                    challenge["id"],
                )
                .execute()
            )

            remaining = (
                self.settings.otp_max_attempts
                - attempts
                - 1
            )

            if remaining <= 0:

                (
                    self.supabase
                    .table("otp_challenges")
                    .delete()
                    .eq(
                        "id",
                        challenge["id"],
                    )
                    .execute()
                )

                raise OTPMaxAttemptsError(
                    "Too many incorrect attempts. "
                    "Please request a new code."
                )

            raise OTPInvalidError(
                f"Incorrect verification code. "
                f"{remaining} attempts remaining."
            )

        # -----------------------------------------------------
        # OTP is correct.
        #
        # Delete it so it cannot be reused.
        # -----------------------------------------------------

        (
            self.supabase
            .table("otp_challenges")
            .delete()
            .eq(
                "id",
                challenge["id"],
            )
            .execute()
        )

        return True

    # ---------------------------------------------------------
    # Resend OTP
    # ---------------------------------------------------------

    def resend_otp(
        self,
        email: str,
        purpose: str,
        user_id: str | None = None,
    ) -> str:
        """
        Generate and store a new OTP.

        Returns the plain OTP so the caller can send the
        email in the background.
        """

        return self.create_otp(
            email=email,
            purpose=purpose,
            user_id=user_id,
        )