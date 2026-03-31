import secrets

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

import models
import schemas
from database import DEV_SEED_ENABLED, get_db
from routers.auth import get_password_hash


router = APIRouter(prefix="/dev", tags=["dev"])

SEED_COLLEGE_NAME = "AMS Demo College"
SEED_ACCOUNTS = (
    {
        "role": "principal",
        "name": "Dr. Priya Raman",
        "username": "principal@college.edu",
        "email": "principal@college.edu",
    },
    {
        "role": "hod",
        "name": "Dr. Helen Carter",
        "username": "hod.cs@college.edu",
        "email": "hod.cs@college.edu",
    },
    {
        "role": "lecturer",
        "name": "Prof. Samuel Reed",
        "username": "lecturer@college.edu",
        "email": "lecturer@college.edu",
    },
    {
        "role": "student",
        "name": "Aisha Khan",
        "username": "4AL22CS001",
        "email": "student1@college.edu",
    },
)
SEED_STUDENTS = (
    {
        "name": "Aisha Khan",
        "usn": "4AL22CS001",
        "department": "Computer Science",
    },
    {
        "name": "Maya Patel",
        "usn": "4AL22CS002",
        "department": "Computer Science",
    },
    {
        "name": "Ethan Brooks",
        "usn": "4AL22CS003",
        "department": "Computer Science",
    },
    {
        "name": "Noah Kim",
        "usn": "4AL22IS004",
        "department": "Information Science",
    },
    {
        "name": "Liam Carter",
        "usn": "4AL22CS005",
        "department": "Computer Science",
    },
)
SEED_COURSES = (
    {
        "course_name": "Data Structures",
        "student_usns": ["4AL22CS001", "4AL22CS002", "4AL22CS003", "4AL22CS005"],
    },
    {
        "course_name": "Cloud Foundations",
        "student_usns": ["4AL22CS001", "4AL22CS002", "4AL22IS004", "4AL22CS005"],
    },
)


def _ensure_dev_seed_enabled():
    if not DEV_SEED_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sample data route is disabled",
        )

def _legacy_password_hash() -> str:
    return get_password_hash(secrets.token_urlsafe(32))


def _upsert_user(db: Session, college_id: int, payload: dict) -> models.User:
    user = (
        db.query(models.User)
        .filter(models.User.email == payload["email"].strip().lower())
        .first()
    )
    if not user:
        user = models.User(
            name=payload["name"],
            username=payload["username"],
            email=payload["email"].strip().lower(),
            password_hash=_legacy_password_hash(),
            google_id=payload.get("google_id"),
            role=payload["role"],
            college_id=college_id,
        )
        db.add(user)
        db.flush()
        return user

    user.name = payload["name"]
    user.username = payload["username"]
    user.email = payload["email"].strip().lower()
    user.password_hash = _legacy_password_hash()
    if payload.get("google_id"):
        user.google_id = payload["google_id"]
    user.role = payload["role"]
    user.college_id = college_id
    db.flush()
    return user


def _upsert_student(db: Session, college_id: int, payload: dict) -> models.Student:
    student = db.query(models.Student).filter(models.Student.usn == payload["usn"]).first()
    if not student:
        student = models.Student(
            name=payload["name"],
            usn=payload["usn"],
            department=payload["department"],
            college_id=college_id,
        )
        db.add(student)
        db.flush()
        return student

    student.name = payload["name"]
    student.department = payload["department"]
    student.college_id = college_id
    db.flush()
    return student


@router.post("/seed", response_model=schemas.DevSeedResponse)
def seed_dev_data(db: Session = Depends(get_db)):
    _ensure_dev_seed_enabled()

    college = (
        db.query(models.College).filter(models.College.name == SEED_COLLEGE_NAME).first()
    )
    if not college:
        college = models.College(name=SEED_COLLEGE_NAME)
        db.add(college)
        db.flush()

    seeded_users = [_upsert_user(db, college.id, payload) for payload in SEED_ACCOUNTS]
    lecturer = next(user for user in seeded_users if user.role == "lecturer")

    students = [_upsert_student(db, college.id, payload) for payload in SEED_STUDENTS]
    student_by_usn = {student.usn: student for student in students}

    seeded_courses = []
    for payload in SEED_COURSES:
        course = (
            db.query(models.Course)
            .filter(
                models.Course.course_name == payload["course_name"],
                models.Course.lecturer_id == lecturer.id,
                models.Course.college_id == college.id,
            )
            .first()
        )
        if not course:
            course = models.Course(
                course_name=payload["course_name"],
                lecturer_id=lecturer.id,
                college_id=college.id,
            )
            db.add(course)
            db.flush()

        course.course_name = payload["course_name"]
        course.lecturer_id = lecturer.id
        course.college_id = college.id
        course.students = [student_by_usn[usn] for usn in payload["student_usns"]]
        db.flush()
        seeded_courses.append(course)

    db.commit()

    for row in [college, *seeded_users, *students, *seeded_courses]:
        db.refresh(row)

    return schemas.DevSeedResponse(
        message="Sample university data is ready",
        college_id=college.id,
        accounts=[
            schemas.SeedAccount(
                user_id=user.id,
                role=user.role,
                name=user.name,
                email=user.email,
                google_id=user.google_id,
            )
            for user in seeded_users
        ],
        courses=[
            schemas.SeedCourse(
                id=course.id,
                course_name=course.course_name,
                student_ids=sorted(student.id for student in course.students),
                student_count=len(course.students),
            )
            for course in seeded_courses
        ],
        students=sorted(students, key=lambda item: item.name.lower()),
    )
