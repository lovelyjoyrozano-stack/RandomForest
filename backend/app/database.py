"""SQLAlchemy engine, session dependency and light schema upgrades."""
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker
from sqlalchemy.pool import StaticPool

from .config import get_settings


class Base(DeclarativeBase):
    pass


def _normalise_url(url: str) -> str:
    # Accept the short forms hosting providers hand out; we use psycopg v3.
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://"):]
    if url.startswith("postgresql://"):
        url = "postgresql+psycopg://" + url[len("postgresql://"):]
    return url


def _make_engine():
    url = _normalise_url(get_settings().database_url)
    if url.startswith("sqlite"):
        kwargs = {"connect_args": {"check_same_thread": False}}
        if ":memory:" in url or url in {"sqlite://", "sqlite:///"}:
            kwargs["poolclass"] = StaticPool
        return create_engine(url, **kwargs)
    return create_engine(url, pool_pre_ping=True)


engine = _make_engine()
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# Columns added by this version. Existing databases get them automatically at
# startup (create_all never alters an existing table).
_NEW_COLUMNS: dict[str, dict[str, str]] = {
    "users": {"created_at": "TIMESTAMP", "email": "VARCHAR(254)"},
    "farms": {
        "area_hectares": "DOUBLE PRECISION",
        "city": "VARCHAR(100)",
        "created_at": "TIMESTAMP",
    },
    "climate_readings": {"created_at": "TIMESTAMP"},
    "planting_assessments": {"created_at": "TIMESTAMP"},
    "productivity_records": {"created_at": "TIMESTAMP"},
}


def init_db() -> None:
    from . import models  # noqa: F401  (register tables)

    Base.metadata.create_all(engine)

    inspector = inspect(engine)
    _verify_primary_keys(inspector)
    with engine.begin() as conn:
        for table, columns in _NEW_COLUMNS.items():
            if not inspector.has_table(table):
                continue
            existing = {c["name"] for c in inspector.get_columns(table)}
            for name, ddl_type in columns.items():
                if name not in existing:
                    conn.execute(text(f'ALTER TABLE {table} ADD COLUMN {name} {ddl_type}'))
        conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email ON users (email) WHERE email IS NOT NULL"))


def _verify_primary_keys(inspector) -> None:
    """The original schema was not shipped with the project, so primary-key
    names for two tables are inferred. Fail early with a clear message if the
    live database disagrees instead of erroring on the first query."""
    problems = []
    for table in Base.metadata.sorted_tables:
        if not inspector.has_table(table.name):
            continue
        expected = [c.name for c in table.primary_key.columns]
        actual = inspector.get_pk_constraint(table.name).get("constrained_columns") or []
        if actual and actual != expected:
            problems.append(f"{table.name}: database has {actual}, models.py expects {expected}")
    if problems:
        raise RuntimeError(
            "Primary key mismatch between the database and app/models.py - "
            "rename the attribute/column in models.py to match:\n  " + "\n  ".join(problems)
        )


def check_connection() -> None:
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
