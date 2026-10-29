from fastapi import APIRouter, Depends, HTTPException, Request
from datetime import datetime, timedelta, timezone
import hashlib, secrets, smtplib
from email.message import EmailMessage
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import User, PasswordResetToken
from ..config import get_settings
from ..schemas import LoginIn, RegisterIn, TokenOut, UserOut, ForgotPasswordIn, ResetPasswordIn
from ..security import (
    burn_hash_time, create_access_token, get_current_user, hash_password,
    login_throttle, verify_password,
)

router = APIRouter(tags=["Authentication"])


@router.post("/register", status_code=201)
def register(data: RegisterIn, db: Session = Depends(get_db)):
    taken = db.scalar(select(User.user_id).where(func.lower(User.username) == data.username.lower()))
    if taken:
        raise HTTPException(status_code=409, detail="Username already exists.")
    if db.scalar(select(User.user_id).where(func.lower(User.email) == data.email.lower())):
        raise HTTPException(status_code=409, detail="Email address already exists.")

    user = User(
        full_name=data.full_name,
        username=data.username,
        email=data.email,
        password=hash_password(data.password),
        role="Farmer",
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:  # lost a race with another registration
        db.rollback()
        raise HTTPException(status_code=409, detail="Username already exists.")
    db.refresh(user)
    return {"message": "Farmer registered successfully.", "user": UserOut.model_validate(user)}


@router.post("/login", response_model=TokenOut)
def login(data: LoginIn, request: Request, db: Session = Depends(get_db)):
    username = data.username.strip()
    key = f"{request.client.host if request.client else '?'}:{username.lower()}"
    login_throttle.check(key)

    user = db.scalar(select(User).where(User.username == username))
    if user is None:
        burn_hash_time(data.password)
        ok = False
    else:
        ok = verify_password(data.password, user.password)

    # One message for unknown user / wrong password / wrong role: no account probing.
    if not ok or (data.role and data.role.strip().lower() != (user.role or "").lower()):
        login_throttle.fail(key)
        raise HTTPException(status_code=401, detail="Invalid username or password.")

    login_throttle.reset(key)
    token, expires_in = create_access_token(user)
    return TokenOut(
        message="Login successful.",
        access_token=token,
        expires_in=expires_in,
        user=UserOut.model_validate(user),
    )


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user


GENERIC_RESET_MESSAGE = "If an account with that email exists and email delivery is available, password-reset instructions will be sent."


def _send_reset_email(email: str, reset_url: str) -> None:
    settings = get_settings()
    if not all([settings.email_host, settings.email_username, settings.email_password, settings.email_from]):
        raise RuntimeError("Email service is not configured")
    msg = EmailMessage()
    msg["Subject"] = "Password reset request"
    msg["From"] = settings.email_from
    msg["To"] = email
    msg.set_content(
        "A password reset was requested for your account. Open this link within "
        f"{settings.password_reset_expire_minutes} minutes:\n\n{reset_url}\n\n"
        "If you did not request this, you can ignore this email."
    )
    with smtplib.SMTP(settings.email_host, settings.email_port, timeout=15) as server:
        if settings.email_use_tls:
            server.starttls()
        server.login(settings.email_username, settings.email_password)
        server.send_message(msg)


@router.post("/password/forgot")
def forgot_password(data: ForgotPasswordIn, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(func.lower(User.email) == data.email.lower()))
    if user is not None:
        settings = get_settings()
        raw_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw_token.encode("utf-8")).hexdigest()
        now = datetime.now(timezone.utc).replace(tzinfo=None)
        db.query(PasswordResetToken).filter(
            PasswordResetToken.user_id == user.user_id,
            PasswordResetToken.used.is_(False),
        ).update({PasswordResetToken.used: True}, synchronize_session=False)
        row = PasswordResetToken(
            user_id=user.user_id, token_hash=token_hash,
            expires_at=now + timedelta(minutes=settings.password_reset_expire_minutes),
        )
        db.add(row)
        db.commit()
        reset_url = settings.password_reset_url.rstrip("#") + "#token=" + raw_token
        try:
            _send_reset_email(user.email, reset_url)
        except Exception:
            # Do not log the email address or reset token. Keep the public response
            # generic so it does not disclose whether the account exists.
            db.delete(row)
            db.commit()
            return {"message": GENERIC_RESET_MESSAGE}
    return {"message": GENERIC_RESET_MESSAGE}


@router.post("/password/reset")
def reset_password(data: ResetPasswordIn, db: Session = Depends(get_db)):
    token_hash = hashlib.sha256(data.token.encode("utf-8")).hexdigest()
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    # Mark expired reset rows as used before checking the presented token.
    db.query(PasswordResetToken).filter(
        PasswordResetToken.expires_at <= now,
        PasswordResetToken.used.is_(False),
    ).update({PasswordResetToken.used: True}, synchronize_session=False)
    db.flush()
    row = db.scalar(select(PasswordResetToken).where(
        PasswordResetToken.token_hash == token_hash,
        PasswordResetToken.used.is_(False),
        PasswordResetToken.expires_at > now,
    ))
    if row is None:
        raise HTTPException(status_code=400, detail="This password-reset link is invalid or expired. Request a new one.")
    user = db.get(User, row.user_id)
    if user is None:
        row.used = True
        db.commit()
        raise HTTPException(status_code=400, detail="This password-reset link is invalid or expired. Request a new one.")
    user.password = hash_password(data.password)
    row.used = True
    db.query(PasswordResetToken).filter(
        PasswordResetToken.user_id == user.user_id,
        PasswordResetToken.reset_id != row.reset_id,
        PasswordResetToken.used.is_(False),
    ).update({PasswordResetToken.used: True}, synchronize_session=False)
    db.commit()
    return {"message": "Password updated successfully. You can now log in."}
