from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

import models
import schemas
from database import (
    ACCESS_TOKEN_EXPIRE_MINUTES,
    ALGORITHM,
    GOOGLE_CLIENT_ID,
    SECRET_KEY,
    get_db,
)


router = APIRouter(prefix="/auth", tags=["auth"])
security = HTTPBearer(auto_error=False)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expires = datetime.now(timezone.utc) + timedelta(
        minutes=ACCESS_TOKEN_EXPIRE_MINUTES
    )
    to_encode.update({"exp": expires})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def _student_id_for_user(db: Session, user: models.User) -> int | None:
    if user.role != "student":
        return None

    student = (
        db.query(models.Student)
        .filter(
            models.Student.usn == user.username,
            models.Student.college_id == user.college_id,
        )
        .first()
    )
    return student.id if student else None


def _verify_google_token(id_token: str) -> dict:
    if not GOOGLE_CLIENT_ID:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Google Sign-In is not configured on the server.",
        )

    try:
        payload = google_id_token.verify_oauth2_token(
            id_token,
            google_requests.Request(),
            GOOGLE_CLIENT_ID,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Google Sign-In could not be verified.",
        ) from exc

    if not payload.get("email_verified"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Your Google account email is not verified.",
        )

    if not payload.get("email") or not payload.get("sub"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Google Sign-In did not return a valid identity.",
        )

    return payload


def _role_label(role: str) -> str:
    return {
        "principal": "Principal",
        "hod": "HOD",
        "lecturer": "Lecturer",
        "student": "Student",
    }.get(role.strip().lower(), role.strip().title())


def _build_auth_response(db: Session, user: models.User) -> schemas.AuthResponse:
    student_id = _student_id_for_user(db, user)
    token = create_access_token(
        {"sub": str(user.id), "role": user.role, "email": user.email}
    )
    return schemas.AuthResponse(
        user_id=user.id,
        email=user.email,
        role=user.role,
        name=user.name,
        college_id=user.college_id,
        student_id=student_id,
        access_token=token,
    )


@router.get("/google/config", response_model=schemas.GoogleClientConfigResponse)
def get_google_client_config():
    client_id = GOOGLE_CLIENT_ID.strip() or None
    return schemas.GoogleClientConfigResponse(client_id=client_id)


@router.post("/google", response_model=schemas.AuthResponse)
def authenticate_with_google(
    payload: schemas.GoogleAuthRequest,
    db: Session = Depends(get_db),
):
    google_payload = _verify_google_token(payload.id_token)
    email = google_payload["email"].strip().lower()
    google_subject = google_payload["sub"].strip()
    selected_role = payload.role.strip().lower()

    user = (
        db.query(models.User)
        .filter(
            models.User.email == email,
            models.User.role == selected_role,
        )
        .first()
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                f"Your account is not registered as a {_role_label(selected_role)}. "
                "Contact administrator."
            ),
        )

    if user.google_id and user.google_id != google_subject:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This Google account does not match the registered college profile.",
        )

    if user.google_id != google_subject or user.email != email:
        user.google_id = google_subject
        user.email = email
        db.commit()
        db.refresh(user)

    return _build_auth_response(db, user)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    db: Session = Depends(get_db),
):
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
    )
    if credentials is None:
        raise credentials_error
    try:
        payload = jwt.decode(
            credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM]
        )
        user_id = int(payload.get("sub", "0"))
    except (JWTError, ValueError):
        raise credentials_error

    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise credentials_error
    return user


@router.get("/me", response_model=schemas.CurrentUserResponse)
def get_me(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return schemas.CurrentUserResponse(
        user_id=current_user.id,
        email=current_user.email,
        role=current_user.role,
        name=current_user.name,
        college_id=current_user.college_id,
        student_id=_student_id_for_user(db, current_user),
    )


def require_roles(*roles: str):
    def dependency(current_user=Depends(get_current_user)):
        if current_user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Only {', '.join(roles)} can access this endpoint",
            )
        return current_user

    return dependency
