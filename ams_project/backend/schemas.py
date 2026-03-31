from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class GoogleAuthRequest(BaseModel):
    id_token: str = Field(..., min_length=20)
    role: Literal["principal", "hod", "lecturer", "student"]


class GoogleClientConfigResponse(BaseModel):
    client_id: str | None = None


class AuthResponse(BaseModel):
    user_id: int
    email: EmailStr
    role: str
    name: str
    college_id: int
    student_id: int | None = None
    access_token: str
    token_type: str = "bearer"


class CurrentUserResponse(BaseModel):
    user_id: int
    email: EmailStr
    role: str
    name: str
    college_id: int
    student_id: int | None = None


class StudentSummary(ORMModel):
    id: int
    name: str
    usn: str
    department: str


class CourseSummary(BaseModel):
    id: int
    course_name: str
    lecturer_id: int | None = None
    lecturer_name: str | None = None
    student_count: int = 0


class AttendanceStatus(BaseModel):
    student_id: int
    status: Literal["present", "absent"]


class MarkAttendanceRequest(BaseModel):
    course_id: int
    date: date
    records: list[AttendanceStatus]


class AttendanceResult(BaseModel):
    message: str
    updated_records: int


class CourseAttendanceItem(BaseModel):
    student_id: int
    student_name: str
    usn: str
    department: str
    status: Literal["present", "absent"]


class SubjectAttendance(BaseModel):
    course_id: int
    course_name: str
    present_classes: int
    total_classes: int
    attendance_percentage: float


class AttendanceRecordOut(BaseModel):
    id: int
    student_id: int
    course_id: int
    course_name: str
    date: date
    status: Literal["present", "absent"]


class StudentAttendanceResponse(BaseModel):
    student_id: int
    student_name: str
    attendance_percentage: float
    present_classes: int
    total_classes: int
    subject_breakdown: list[SubjectAttendance]
    history: list[AttendanceRecordOut]


class LecturerSummary(ORMModel):
    id: int
    name: str
    email: EmailStr


class LecturerCreate(BaseModel):
    name: str = Field(..., min_length=3)
    email: EmailStr


class CourseAssignRequest(BaseModel):
    course_name: str = Field(..., min_length=3)
    lecturer_id: int
    college_id: int
    student_ids: list[int] = Field(default_factory=list)


class DepartmentAnalytics(BaseModel):
    department: str
    total_students: int
    total_records: int
    present_count: int
    attendance_percentage: float


class CollegeAnalytics(BaseModel):
    total_students: int
    total_records: int
    present_count: int
    attendance_percentage: float
    departments: list[DepartmentAnalytics]


class ReportItem(BaseModel):
    department: str
    course_name: str
    lecturer_name: str
    attendance_percentage: float
    total_classes: int


class SeedAccount(BaseModel):
    user_id: int
    role: str
    name: str
    email: EmailStr
    google_id: str | None = None


class SeedCourse(BaseModel):
    id: int
    course_name: str
    student_ids: list[int]
    student_count: int


class DevSeedResponse(BaseModel):
    message: str
    college_id: int
    accounts: list[SeedAccount]
    courses: list[SeedCourse]
    students: list[StudentSummary]
