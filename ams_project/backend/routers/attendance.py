from collections import defaultdict
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

import models
import schemas
from database import get_db
from routers.auth import get_current_user, require_roles


router = APIRouter(tags=["attendance"])


def _student_from_user(db: Session, current_user):
    return (
        db.query(models.Student)
        .filter(
            models.Student.usn == current_user.username,
            models.Student.college_id == current_user.college_id,
        )
        .first()
    )


@router.get("/students", response_model=list[schemas.StudentSummary])
def get_students(
    course_id: int | None = None,
    department: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role == "student":
        student = _student_from_user(db, current_user)
        return [student] if student else []

    query = db.query(models.Student).filter(
        models.Student.college_id == current_user.college_id
    )

    if department:
        query = query.filter(models.Student.department == department)

    if course_id is not None:
        course = (
            db.query(models.Course)
            .filter(
                models.Course.id == course_id,
                models.Course.college_id == current_user.college_id,
            )
            .first()
        )
        if not course:
            raise HTTPException(status_code=404, detail="Course not found")
        if current_user.role == "lecturer" and course.lecturer_id != current_user.id:
            raise HTTPException(status_code=403, detail="Course not assigned to you")
        query = query.join(
            models.course_enrollments,
            models.Student.id == models.course_enrollments.c.student_id,
        ).filter(models.course_enrollments.c.course_id == course_id)
    elif current_user.role == "lecturer":
        course_ids = [
            course.id
            for course in db.query(models.Course)
            .filter(models.Course.lecturer_id == current_user.id)
            .all()
        ]
        if not course_ids:
            return []
        query = query.join(
            models.course_enrollments,
            models.Student.id == models.course_enrollments.c.student_id,
        ).filter(models.course_enrollments.c.course_id.in_(course_ids))

    return query.order_by(models.Student.name).distinct().all()


@router.get("/courses", response_model=list[schemas.CourseSummary])
def get_courses(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    query = db.query(models.Course).filter(
        models.Course.college_id == current_user.college_id
    )

    if current_user.role == "lecturer":
        query = query.filter(models.Course.lecturer_id == current_user.id)
    elif current_user.role == "student":
        student = _student_from_user(db, current_user)
        if not student:
            return []
        query = (
            query.join(
                models.course_enrollments,
                models.Course.id == models.course_enrollments.c.course_id,
            )
            .filter(models.course_enrollments.c.student_id == student.id)
            .distinct()
        )

    courses = query.order_by(models.Course.course_name).all()
    return [
        schemas.CourseSummary(
            id=course.id,
            course_name=course.course_name,
            lecturer_id=course.lecturer_id,
            lecturer_name=course.lecturer.name if course.lecturer else None,
            student_count=len(course.students),
        )
        for course in courses
    ]


@router.get(
    "/attendance/course/{course_id}",
    response_model=list[schemas.CourseAttendanceItem],
)
def get_course_attendance(
    course_id: int,
    date_value: date = Query(..., alias="date"),
    db: Session = Depends(get_db),
    current_user=Depends(require_roles("lecturer", "hod", "principal")),
):
    course = (
        db.query(models.Course)
        .filter(
            models.Course.id == course_id,
            models.Course.college_id == current_user.college_id,
        )
        .first()
    )
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")
    if current_user.role == "lecturer" and course.lecturer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Course not assigned to you")

    attendance_rows = (
        db.query(models.Attendance)
        .filter(
            models.Attendance.course_id == course_id,
            models.Attendance.date == date_value,
        )
        .all()
    )
    status_map = {row.student_id: row.status for row in attendance_rows}
    return [
        schemas.CourseAttendanceItem(
            student_id=student.id,
            student_name=student.name,
            usn=student.usn,
            department=student.department,
            status=status_map.get(student.id, "present"),
        )
        for student in sorted(course.students, key=lambda item: item.name.lower())
    ]


@router.post(
    "/attendance/mark",
    response_model=schemas.AttendanceResult,
    status_code=status.HTTP_200_OK,
)
def mark_attendance(
    payload: schemas.MarkAttendanceRequest,
    db: Session = Depends(get_db),
    current_user=Depends(require_roles("lecturer")),
):
    course = (
        db.query(models.Course)
        .filter(
            models.Course.id == payload.course_id,
            models.Course.lecturer_id == current_user.id,
        )
        .first()
    )
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")

    enrolled_ids = {student.id for student in course.students}
    updated_records = 0
    for record in payload.records:
        if record.student_id not in enrolled_ids:
            raise HTTPException(
                status_code=400,
                detail=f"Student {record.student_id} is not enrolled in this course",
            )

        row = (
            db.query(models.Attendance)
            .filter(
                models.Attendance.student_id == record.student_id,
                models.Attendance.course_id == payload.course_id,
                models.Attendance.date == payload.date,
            )
            .first()
        )
        if row:
            row.status = record.status
        else:
            db.add(
                models.Attendance(
                    student_id=record.student_id,
                    course_id=payload.course_id,
                    date=payload.date,
                    status=record.status,
                )
            )
        updated_records += 1

    db.commit()
    return {
        "message": "Attendance saved successfully",
        "updated_records": updated_records,
    }


@router.get(
    "/attendance/student/{student_id}",
    response_model=schemas.StudentAttendanceResponse,
)
def get_student_attendance(
    student_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role == "student":
        student = _student_from_user(db, current_user)
        if not student or student.id != student_id:
            raise HTTPException(
                status_code=403,
                detail="Students can only view their own attendance",
            )
    else:
        student = (
            db.query(models.Student)
            .filter(
                models.Student.id == student_id,
                models.Student.college_id == current_user.college_id,
            )
            .first()
        )

    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    records = (
        db.query(models.Attendance)
        .join(models.Course, models.Course.id == models.Attendance.course_id)
        .filter(models.Attendance.student_id == student.id)
        .order_by(models.Attendance.date.desc(), models.Course.course_name)
        .all()
    )

    present_classes = sum(1 for record in records if record.status == "present")
    total_classes = len(records)
    percentage = round((present_classes / total_classes) * 100, 2) if total_classes else 0.0

    course_totals = defaultdict(lambda: {"present": 0, "total": 0, "name": ""})
    for course in student.courses:
        course_totals[course.id]["name"] = course.course_name
    for record in records:
        item = course_totals[record.course_id]
        item["name"] = record.course.course_name
        item["total"] += 1
        if record.status == "present":
            item["present"] += 1

    subject_breakdown = [
        schemas.SubjectAttendance(
            course_id=course_id,
            course_name=values["name"],
            present_classes=values["present"],
            total_classes=values["total"],
            attendance_percentage=round(
                (values["present"] / values["total"]) * 100, 2
            )
            if values["total"]
            else 0.0,
        )
        for course_id, values in sorted(
            course_totals.items(), key=lambda item: item[1]["name"]
        )
    ]

    history = [
        schemas.AttendanceRecordOut(
            id=record.id,
            student_id=record.student_id,
            course_id=record.course_id,
            course_name=record.course.course_name,
            date=record.date,
            status=record.status,
        )
        for record in records
    ]

    return schemas.StudentAttendanceResponse(
        student_id=student.id,
        student_name=student.name,
        attendance_percentage=percentage,
        present_classes=present_classes,
        total_classes=total_classes,
        subject_breakdown=subject_breakdown,
        history=history,
    )
