enum AttendanceMark { present, absent }

extension AttendanceMarkX on AttendanceMark {
  String get apiValue => name;

  String get label => switch (this) {
    AttendanceMark.present => 'Present',
    AttendanceMark.absent => 'Absent',
  };

  static AttendanceMark fromApi(String value) {
    return switch (value) {
      'present' => AttendanceMark.present,
      'absent' => AttendanceMark.absent,
      _ => AttendanceMark.present,
    };
  }
}

enum LoginRole { principal, hod, lecturer, student }

extension LoginRoleX on LoginRole {
  String get apiValue => name;

  String get label => switch (this) {
    LoginRole.principal => 'Principal',
    LoginRole.hod => 'HOD',
    LoginRole.lecturer => 'Lecturer',
    LoginRole.student => 'Student',
  };

  String get helperText => switch (this) {
    LoginRole.principal => 'College-wide oversight and analytics',
    LoginRole.hod => 'Department-level attendance review',
    LoginRole.lecturer => 'Course attendance and reporting',
    LoginRole.student => 'Personal attendance records',
  };

  static LoginRole? fromApi(String value) {
    return switch (value.trim().toLowerCase()) {
      'principal' => LoginRole.principal,
      'hod' => LoginRole.hod,
      'lecturer' => LoginRole.lecturer,
      'student' => LoginRole.student,
      _ => null,
    };
  }
}

class SessionUser {
  const SessionUser({
    required this.userId,
    required this.email,
    required this.role,
    required this.name,
    required this.collegeId,
    this.studentId,
  });

  final int userId;
  final String email;
  final String role;
  final String name;
  final int collegeId;
  final int? studentId;

  bool get isPrincipal => role == 'principal';
  bool get isHod => role == 'hod';
  bool get isLecturer => role == 'lecturer';
  bool get isStudent => role == 'student';
  bool get isSupportedRole => isPrincipal || isHod || isLecturer || isStudent;

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      userId: json['user_id'] as int,
      email: json['email'] as String,
      role: json['role'] as String,
      name: json['name'] as String,
      collegeId: json['college_id'] as int,
      studentId: json['student_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'role': role,
      'name': name,
      'college_id': collegeId,
      'student_id': studentId,
    };
  }
}

class AuthResponse {
  const AuthResponse({
    required this.user,
    required this.accessToken,
    required this.tokenType,
  });

  final SessionUser user;
  final String accessToken;
  final String tokenType;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: SessionUser.fromJson(json),
      accessToken: json['access_token'] as String,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
    );
  }
}

class CourseSummary {
  const CourseSummary({
    required this.id,
    required this.courseName,
    required this.studentCount,
    this.lecturerId,
    this.lecturerName,
  });

  final int id;
  final String courseName;
  final int? lecturerId;
  final String? lecturerName;
  final int studentCount;

  factory CourseSummary.fromJson(Map<String, dynamic> json) {
    return CourseSummary(
      id: json['id'] as int,
      courseName: json['course_name'] as String,
      lecturerId: json['lecturer_id'] as int?,
      lecturerName: json['lecturer_name'] as String?,
      studentCount: json['student_count'] as int? ?? 0,
    );
  }
}

class StudentSummary {
  const StudentSummary({
    required this.id,
    required this.name,
    required this.usn,
    required this.department,
  });

  final int id;
  final String name;
  final String usn;
  final String department;

  factory StudentSummary.fromJson(Map<String, dynamic> json) {
    return StudentSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      usn: json['usn'] as String,
      department: json['department'] as String,
    );
  }
}

class CourseAttendanceItem {
  const CourseAttendanceItem({
    required this.studentId,
    required this.studentName,
    required this.usn,
    required this.department,
    required this.status,
  });

  final int studentId;
  final String studentName;
  final String usn;
  final String department;
  final AttendanceMark status;

  factory CourseAttendanceItem.fromJson(Map<String, dynamic> json) {
    return CourseAttendanceItem(
      studentId: json['student_id'] as int,
      studentName: json['student_name'] as String,
      usn: json['usn'] as String,
      department: json['department'] as String,
      status: AttendanceMarkX.fromApi(json['status'] as String),
    );
  }
}

class AttendanceSheetEntry {
  const AttendanceSheetEntry({
    required this.studentId,
    required this.studentName,
    required this.usn,
    required this.department,
    required this.status,
  });

  final int studentId;
  final String studentName;
  final String usn;
  final String department;
  final AttendanceMark status;

  AttendanceStatus get attendanceStatus =>
      AttendanceStatus(studentId: studentId, status: status);

  AttendanceSheetEntry copyWith({AttendanceMark? status}) {
    return AttendanceSheetEntry(
      studentId: studentId,
      studentName: studentName,
      usn: usn,
      department: department,
      status: status ?? this.status,
    );
  }
}

class AttendanceStatus {
  const AttendanceStatus({required this.studentId, required this.status});

  final int studentId;
  final AttendanceMark status;

  Map<String, dynamic> toJson() {
    return {'student_id': studentId, 'status': status.apiValue};
  }
}

class MarkAttendanceRequest {
  const MarkAttendanceRequest({
    required this.courseId,
    required this.date,
    required this.records,
  });

  final int courseId;
  final DateTime date;
  final List<AttendanceStatus> records;

  factory MarkAttendanceRequest.fromEntries({
    required int courseId,
    required DateTime date,
    required List<AttendanceSheetEntry> entries,
  }) {
    return MarkAttendanceRequest(
      courseId: courseId,
      date: date,
      records: entries.map((entry) => entry.attendanceStatus).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'date': formatApiDate(date),
      'records': records.map((record) => record.toJson()).toList(),
    };
  }
}

class DepartmentAnalytics {
  const DepartmentAnalytics({
    required this.department,
    required this.totalStudents,
    required this.totalRecords,
    required this.presentCount,
    required this.attendancePercentage,
  });

  final String department;
  final int totalStudents;
  final int totalRecords;
  final int presentCount;
  final double attendancePercentage;

  factory DepartmentAnalytics.fromJson(Map<String, dynamic> json) {
    return DepartmentAnalytics(
      department: json['department'] as String,
      totalStudents: json['total_students'] as int,
      totalRecords: json['total_records'] as int,
      presentCount: json['present_count'] as int,
      attendancePercentage: (json['attendance_percentage'] as num).toDouble(),
    );
  }
}

class CollegeAnalytics {
  const CollegeAnalytics({
    required this.totalStudents,
    required this.totalRecords,
    required this.presentCount,
    required this.attendancePercentage,
    required this.departments,
  });

  final int totalStudents;
  final int totalRecords;
  final int presentCount;
  final double attendancePercentage;
  final List<DepartmentAnalytics> departments;

  factory CollegeAnalytics.fromJson(Map<String, dynamic> json) {
    return CollegeAnalytics(
      totalStudents: json['total_students'] as int,
      totalRecords: json['total_records'] as int,
      presentCount: json['present_count'] as int,
      attendancePercentage: (json['attendance_percentage'] as num).toDouble(),
      departments: (json['departments'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                DepartmentAnalytics.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class AttendanceReportItem {
  const AttendanceReportItem({
    required this.department,
    required this.courseName,
    required this.lecturerName,
    required this.attendancePercentage,
    required this.totalClasses,
  });

  final String department;
  final String courseName;
  final String lecturerName;
  final double attendancePercentage;
  final int totalClasses;

  factory AttendanceReportItem.fromJson(Map<String, dynamic> json) {
    return AttendanceReportItem(
      department: json['department'] as String,
      courseName: json['course_name'] as String,
      lecturerName: json['lecturer_name'] as String,
      attendancePercentage: (json['attendance_percentage'] as num).toDouble(),
      totalClasses: json['total_classes'] as int,
    );
  }
}

class SubjectAttendanceSummary {
  const SubjectAttendanceSummary({
    required this.courseId,
    required this.courseName,
    required this.presentClasses,
    required this.totalClasses,
    required this.attendancePercentage,
  });

  final int courseId;
  final String courseName;
  final int presentClasses;
  final int totalClasses;
  final double attendancePercentage;

  factory SubjectAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return SubjectAttendanceSummary(
      courseId: json['course_id'] as int,
      courseName: json['course_name'] as String,
      presentClasses: json['present_classes'] as int,
      totalClasses: json['total_classes'] as int,
      attendancePercentage: (json['attendance_percentage'] as num).toDouble(),
    );
  }
}

class AttendanceHistoryItem {
  const AttendanceHistoryItem({
    required this.id,
    required this.studentId,
    required this.courseId,
    required this.courseName,
    required this.date,
    required this.status,
  });

  final int id;
  final int studentId;
  final int courseId;
  final String courseName;
  final DateTime date;
  final AttendanceMark status;

  factory AttendanceHistoryItem.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryItem(
      id: json['id'] as int,
      studentId: json['student_id'] as int,
      courseId: json['course_id'] as int,
      courseName: json['course_name'] as String,
      date: DateTime.parse(json['date'] as String),
      status: AttendanceMarkX.fromApi(json['status'] as String),
    );
  }
}

class StudentAttendanceSummary {
  const StudentAttendanceSummary({
    required this.studentId,
    required this.studentName,
    required this.attendancePercentage,
    required this.presentClasses,
    required this.totalClasses,
    required this.subjectBreakdown,
    required this.history,
  });

  final int studentId;
  final String studentName;
  final double attendancePercentage;
  final int presentClasses;
  final int totalClasses;
  final List<SubjectAttendanceSummary> subjectBreakdown;
  final List<AttendanceHistoryItem> history;

  factory StudentAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceSummary(
      studentId: json['student_id'] as int,
      studentName: json['student_name'] as String,
      attendancePercentage: (json['attendance_percentage'] as num).toDouble(),
      presentClasses: json['present_classes'] as int,
      totalClasses: json['total_classes'] as int,
      subjectBreakdown:
          (json['subject_breakdown'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (item) => SubjectAttendanceSummary.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      history: (json['history'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                AttendanceHistoryItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

String formatApiDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
