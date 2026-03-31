import secrets

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

import models
import schemas
from database import get_db
from routers.auth import get_password_hash, require_roles


router = APIRouter(tags=["management"])


def _department_summary(db: Session, college_id: int, department: str):
    students = (
        db.query(models.Student)
        .filter(
            models.Student.college_id == college_id,
            models.Student.department == department,
        )
        .all()
    )
    student_ids = [student.id for student in students]
    attendance_rows = (
        db.query(models.Attendance)
        .filter(models.Attendance.student_id.in_(student_ids))
        .all()
        if student_ids
        else []
    )
    total_records = len(attendance_rows)
    present_count = sum(1 for row in attendance_rows if row.status == "present")
    return schemas.DepartmentAnalytics(
        department=department,
        total_students=len(students),
        total_records=total_records,
        present_count=present_count,
        attendance_percentage=round((present_count / total_records) * 100, 2)
        if total_records
        else 0.0,
    )


@router.get("/lecturers", response_model=list[schemas.LecturerSummary])
def get_lecturers(
    db: Session = Depends(get_db),
    current_user=Depends(require_roles("hod", "principal")),
):
    return (
        db.query(models.User)
        .filter(
            models.User.role == "lecturer",
            models.User.college_id == current_user.college_id,
        )
        .order_by(models.User.name)
        .all()
    )


@router.post(
    "/lecturers",
    response_model=schemas.LecturerSummary,
    status_code=status.HTTP_201_CREATED,
)
def create_lecturer(
    payload: schemas.LecturerCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_roles("hod")),
):
    existing_user = (
        db.query(models.User)
        .filter(
            or_(
                models.User.email == payload.email,
                models.User.username == payload.email,
            )
        )
        .first()
    )
    if existing_user:
        raise HTTPException(status_code=400, detail="Lecturer email already exists")

    lecturer = models.User(
        name=payload.name,
        username=payload.email.lower(),
        email=payload.email.lower(),
        password_hash=get_password_hash(secrets.token_urlsafe(32)),
        role="lecturer",
        college_id=current_user.college_id,
    )
    db.add(lecturer)
    db.commit()
    db.refresh(lecturer)
    return lecturer


@router.post(
    "/courses/assign",
    response_model=schemas.CourseSummary,
    status_code=status.HTTP_201_CREATED,
)
def assign_course(
    payload: schemas.CourseAssignRequest,
    db: Session = Depends(get_db),
    current_user=Depends(require_roles("hod")),
):
    if payload.college_id != current_user.college_id:
        raise HTTPException(status_code=403, detail="Invalid college assignment")

    lecturer = (
        db.query(models.User)
        .filter(
            models.User.id == payload.lecturer_id,
            models.User.role == "lecturer",
            models.User.college_id == current_user.college_id,
        )
        .first()
    )
    if not lecturer:
        raise HTTPException(status_code=404, detail="Lecturer not found")

    students = (
        db.query(models.Student)
        .filter(
            models.Student.college_id == current_user.college_id,
            models.Student.id.in_(payload.student_ids),
        )
        .all()
        if payload.student_ids
        else []
    )

    course = models.Course(
        course_name=payload.course_name,
        lecturer_id=payload.lecturer_id,
        college_id=current_user.college_id,
        students=students,
    )
    db.add(course)
    db.commit()
    db.refresh(course)

    return schemas.CourseSummary(
        id=course.id,
        course_name=course.course_name,
        lecturer_id=course.lecturer_id,
        lecturer_name=lecturer.name,
        student_count=len(students),
    )


@router.get("/analytics/department", response_model=schemas.DepartmentAnalytics)
def get_department_attendance(
    department: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_roles("hod", "principal")),
):
    return _department_summary(db, current_user.college_id, department)


@router.get("/analytics/departments", response_model=list[schemas.DepartmentAnalytics])
def get_department_analytics(
    db: Session = Depends(get_db),
    current_user=Depends(require_roles("hod", "principal")),
):
    department_names = [
        row[0]
        for row in db.query(models.Student.department)
        .filter(models.Student.college_id == current_user.college_id)
        .distinct()
        .order_by(models.Student.department)
        .all()
    ]
    return [
        _department_summary(db, current_user.college_id, department)
        for department in department_names
    ]


@router.get("/analytics/college", response_model=schemas.CollegeAnalytics)
def get_college_analytics(
    db: Session = Depends(get_db),
    current_user=Depends(require_roles("principal")),
):
    department_names = [
        row[0]
        for row in db.query(models.Student.department)
        .filter(models.Student.college_id == current_user.college_id)
        .distinct()
        .order_by(models.Student.department)
        .all()
    ]
    departments = [
        _department_summary(db, current_user.college_id, department)
        for department in department_names
    ]
    total_students = sum(item.total_students for item in departments)
    total_records = sum(item.total_records for item in departments)
    present_count = sum(item.present_count for item in departments)
    return schemas.CollegeAnalytics(
        total_students=total_students,
        total_records=total_records,
        present_count=present_count,
        attendance_percentage=round((present_count / total_records) * 100, 2)
        if total_records
        else 0.0,
        departments=departments,
    )


@router.get("/reports/attendance", response_model=list[schemas.ReportItem])
def get_attendance_reports(
    db: Session = Depends(get_db),
    current_user=Depends(require_roles("principal")),
):
    courses = (
        db.query(models.Course)
        .filter(models.Course.college_id == current_user.college_id)
        .order_by(models.Course.course_name)
        .all()
    )
    report = []
    for course in courses:
        total_classes = len(course.attendance_records)
        present_count = sum(
            1 for record in course.attendance_records if record.status == "present"
        )
        departments = sorted({student.department for student in course.students})
        report.append(
            schemas.ReportItem(
                department=", ".join(departments) if departments else "Not assigned",
                course_name=course.course_name,
                lecturer_name=course.lecturer.name if course.lecturer else "Unknown",
                attendance_percentage=round((present_count / total_classes) * 100, 2)
                if total_classes
                else 0.0,
                total_classes=total_classes,
            )
        )
    return report
