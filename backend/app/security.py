"""Password hashing, JWT issue/verify, auth dependencies, login throttling."""
import time
from datetime import datetime, timedelta, timezone
from threading import Lock

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .config import get_settings
from .database import get_db
from .models import User

MAX_PASSWORD_BYTES = 72  # bcrypt's hard limit

bearer_scheme = HTTPBearer(auto_error=False)


# ---------------------------------------------------------------- passwords
def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("ascii")


def verify_password(password: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8")[:MAX_PASSWORD_BYTES], hashed.encode("ascii"))
    except (ValueError, TypeError):
        return False


# Used to spend the same time on unknown usernames as on wrong passwords.
_DUMMY_HASH = hash_password("not-a-real-password")


def burn_hash_time(password: str) -> None:
    verify_password(password, _DUMMY_HASH)


# --------------------------------------------------------------------- JWT
def create_access_token(user: User) -> tuple[str, int]:
    settings = get_settings()
    expires = timedelta(minutes=settings.jwt_expire_minutes)
    payload = {
        "sub": str(user.user_id),
        "role": user.role,
        "exp": datetime.now(timezone.utc) + expires,
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm="HS256")
    return token, int(expires.total_seconds())


def _unauthorized(detail: str = "Not authenticated.") -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise _unauthorized()
    try:
        payload = jwt.decode(credentials.credentials, get_settings().jwt_secret, algorithms=["HS256"])
        user_id = int(payload["sub"])
    except jwt.ExpiredSignatureError:
        raise _unauthorized("Session expired. Please log in again.")
    except (jwt.PyJWTError, KeyError, ValueError):
        raise _unauthorized("Invalid session. Please log in again.")

    user = db.get(User, user_id)
    if user is None:
        raise _unauthorized("Account no longer exists.")
    return user


def is_admin(user: User) -> bool:
    return (user.role or "").lower() == "admin"


def require_admin(user: User = Depends(get_current_user)) -> User:
    if not is_admin(user):
        raise HTTPException(status_code=403, detail="Administrator access required.")
    return user


# --------------------------------------------------------- login throttling
class LoginThrottle:
    """In-memory brute-force guard: lock a key after N failures for a while.

    Per-process only. Behind several workers, use Redis or a reverse-proxy
    rate limit instead.
    """

    def __init__(self, max_failures: int = 5, lock_seconds: int = 300):
        self.max_failures = max_failures
        self.lock_seconds = lock_seconds
        self._failures: dict[str, tuple[int, float]] = {}
        self._lock = Lock()

    def check(self, key: str) -> None:
        with self._lock:
            count, since = self._failures.get(key, (0, 0.0))
            if count >= self.max_failures:
                remaining = self.lock_seconds - (time.monotonic() - since)
                if remaining > 0:
                    raise HTTPException(
                        status_code=429,
                        detail=f"Too many failed attempts. Try again in {int(remaining // 60) + 1} minute(s).",
                    )
                del self._failures[key]

    def fail(self, key: str) -> None:
        with self._lock:
            count, _ = self._failures.get(key, (0, 0.0))
            self._failures[key] = (count + 1, time.monotonic())

    def reset(self, key: str) -> None:
        with self._lock:
            self._failures.pop(key, None)


login_throttle = LoginThrottle()
