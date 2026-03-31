import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy.engine import make_url
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import Session, declarative_base, sessionmaker


load_dotenv(Path(__file__).resolve().parent / ".env")


def _env_flag(name: str, default: str = "false") -> bool:
    return os.getenv(name, default).strip().lower() in {"1", "true", "yes", "on"}


DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./ams_dev.db")
SECRET_KEY = os.getenv("AMS_SECRET_KEY", "ams-dev-secret-key")
GOOGLE_CLIENT_ID = os.getenv("AMS_GOOGLE_CLIENT_ID", os.getenv("GOOGLE_CLIENT_ID", ""))
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 8 * 60
DEV_SEED_ENABLED = _env_flag("AMS_ENABLE_DEV_SEED", "true")


def _validate_database_url(database_url: str) -> None:
    if database_url.startswith("sqlite"):
        return

    try:
        parsed_url = make_url(database_url)
    except Exception as exc:
        raise RuntimeError(
            "DATABASE_URL is invalid. If your database password contains special "
            "characters like @, :, /, ?, #, [ or ], URL-encode the password "
            "before saving it."
        ) from exc

    host = (parsed_url.host or "").strip()
    if not host:
        raise RuntimeError("DATABASE_URL is missing a hostname.")

    if "@" in host:
        raise RuntimeError(
            "DATABASE_URL appears malformed: the hostname contains '@'. This "
            "usually means the database password contains '@' and was not "
            "URL-encoded."
        )


_validate_database_url(DATABASE_URL)

engine_options = {"future": True, "pool_pre_ping": True}
if DATABASE_URL.startswith("sqlite"):
    engine_options["connect_args"] = {"check_same_thread": False}

engine = create_engine(DATABASE_URL, **engine_options)
SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
    expire_on_commit=False,
    class_=Session,
)
Base = declarative_base()


def ensure_database_schema():
    Base.metadata.create_all(bind=engine)

    with engine.begin() as connection:
        inspector = inspect(connection)
        if "users" not in inspector.get_table_names():
            return

        columns = {column["name"] for column in inspector.get_columns("users")}
        if "google_id" not in columns:
            connection.execute(text("ALTER TABLE users ADD COLUMN google_id VARCHAR(255)"))

        indexes = {index["name"] for index in inspector.get_indexes("users")}
        if "ix_users_google_id" not in indexes:
            connection.execute(
                text("CREATE UNIQUE INDEX ix_users_google_id ON users (google_id)")
            )


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
