"""Compatibility entry point: `uvicorn main:app --reload` still works."""
from app.main import app  # noqa: F401
