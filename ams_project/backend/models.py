from sqlalchemy import Column, Date, ForeignKey, Integer, String, Table, UniqueConstraint
from sqlalchemy.orm import relationship

from database import Base


course_enrollments = Table(
    "course_enrollments",
    Base.metadata,
    Column("course_id", ForeignKey("courses.id"), primary_key=True),
    Column("student_id", ForeignKey("students.id"), primary_key=True),
)


class College(Base):
    __tablename__ = "colleges"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False, unique=True)

    users = relationship("User", back_populates="college", cascade="all, delete-orphan")
    students = relationship(
        "Student", back_populates="college", cascade="all, delete-orphan"
    )
    courses = relationship("Course", back_populates="college", cascade="all, delete-orphan")


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False)
    username = Column(String(100), nullable=False, unique=True, index=True)
    email = Column(String(120), nullable=False, unique=True, index=True)
    password_hash = Column(String(255), nullable=False)
    google_id = Column(String(255), nullable=True, unique=True, index=True)
    role = Column(String(20), nullable=False, index=True)
    college_id = Column(Integer, ForeignKey("colleges.id"), nullable=False)

    college = relationship("College", back_populates="users")
    courses_taught = relationship("Course", back_populates="lecturer")


class Student(Base):
    __tablename__ = "students"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False)
    usn = Column(String(60), nullable=False, unique=True, index=True)
    department = Column(String(80), nullable=False, index=True)
    college_id = Column(Integer, ForeignKey("colleges.id"), nullable=False)

    college = relationship("College", back_populates="students")
    courses = relationship(
        "Course", secondary=course_enrollments, back_populates="students"
    )
    attendance_records = relationship(
        "Attendance", back_populates="student", cascade="all, delete-orphan"
    )


class Course(Base):
    __tablename__ = "courses"

    id = Column(Integer, primary_key=True, index=True)
    course_name = Column(String(120), nullable=False, index=True)
    lecturer_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    college_id = Column(Integer, ForeignKey("colleges.id"), nullable=False)

    lecturer = relationship("User", back_populates="courses_taught")
    college = relationship("College", back_populates="courses")
    students = relationship(
        "Student", secondary=course_enrollments, back_populates="courses"
    )
    attendance_records = relationship(
        "Attendance", back_populates="course", cascade="all, delete-orphan"
    )


class Attendance(Base):
    __tablename__ = "attendance"
    __table_args__ = (
        UniqueConstraint("student_id", "course_id", "date", name="uq_attendance_row"),
    )

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False)
    course_id = Column(Integer, ForeignKey("courses.id"), nullable=False)
    date = Column(Date, nullable=False, index=True)
    status = Column(String(10), nullable=False, default="present")

    student = relationship("Student", back_populates="attendance_records")
    course = relationship("Course", back_populates="attendance_records")
