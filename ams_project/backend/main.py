from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

import models
from database import DATABASE_URL, DEV_SEED_ENABLED, GOOGLE_CLIENT_ID, ensure_database_schema
from routers import attendance, auth, dev, management


ensure_database_schema()

app = FastAPI(title="AMS - Attendance Master Scholar", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(attendance.router)
app.include_router(management.router)
app.include_router(dev.router)


@app.on_event("startup")
def print_startup_notes():
    notes = (
        "",
        "AMS backend started successfully",
        "Local API: http://127.0.0.1:8000",
        "Swagger docs: http://127.0.0.1:8000/docs",
        "Android emulator base URL: http://10.0.2.2:8000",
        f"Database URL: {DATABASE_URL}",
        f"Google client configured: {bool(GOOGLE_CLIENT_ID)}",
        f"Sample data endpoint enabled: {DEV_SEED_ENABLED}",
        "Google auth endpoint: POST http://127.0.0.1:8000/auth/google",
        "Session endpoint: GET http://127.0.0.1:8000/auth/me",
        "",
    )
    for line in notes:
        print(line, flush=True)


@app.get("/")
def health_check():
    return {
        "message": "AMS backend is running",
        "docs": "/docs",
        "auth_provider": "google",
        "dev_seed_enabled": DEV_SEED_ENABLED,
        "database_tables": sorted(models.Base.metadata.tables.keys()),
    }
