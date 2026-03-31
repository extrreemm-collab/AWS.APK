import 'package:ams_frontend/models.dart';
import 'package:ams_frontend/services/api.dart';
import 'package:ams_frontend/services/google_auth.dart';
import 'package:ams_frontend/services/session_store.dart';
import 'package:ams_frontend/state/session_controller.dart';

class FakeAmsApi implements AmsApi {
  FakeAmsApi({
    this.courses = const [],
    Map<int, List<StudentSummary>>? studentsByCourse,
    Map<String, Map<int, AttendanceMark>>? savedStatusesByCourseDate,
    this.currentUser = _defaultLecturer,
    this.collegeAnalytics = const CollegeAnalytics(
      totalStudents: 0,
      totalRecords: 0,
      presentCount: 0,
      attendancePercentage: 0,
      departments: <DepartmentAnalytics>[],
    ),
    this.departmentAnalytics = const <DepartmentAnalytics>[],
    this.reports = const <AttendanceReportItem>[],
    this.studentAttendance = const StudentAttendanceSummary(
      studentId: 0,
      studentName: '',
      attendancePercentage: 0,
      presentClasses: 0,
      totalClasses: 0,
      subjectBreakdown: <SubjectAttendanceSummary>[],
      history: <AttendanceHistoryItem>[],
    ),
    this.saveError,
  }) : studentsByCourse = studentsByCourse ?? <int, List<StudentSummary>>{},
       savedStatusesByCourseDate =
           savedStatusesByCourseDate ?? <String, Map<int, AttendanceMark>>{};

  static const SessionUser _defaultLecturer = SessionUser(
    userId: 21,
    email: 'lecturer@college.edu',
    role: 'lecturer',
    name: 'Prof. Samuel Reed',
    collegeId: 1,
  );

  @override
  String get baseUrl => 'http://example.test';

  @override
  Future<String?> fetchGoogleClientId() async => null;

  final List<CourseSummary> courses;
  final Map<int, List<StudentSummary>> studentsByCourse;
  final Map<String, Map<int, AttendanceMark>> savedStatusesByCourseDate;
  final SessionUser currentUser;
  final CollegeAnalytics collegeAnalytics;
  final List<DepartmentAnalytics> departmentAnalytics;
  final List<AttendanceReportItem> reports;
  final StudentAttendanceSummary studentAttendance;
  final ApiException? saveError;
  final List<MarkAttendanceRequest> markedRequests = <MarkAttendanceRequest>[];

  @override
  Future<AuthResponse> authenticateWithGoogle({
    required String idToken,
    required String role,
  }) async {
    return AuthResponse(
      user: currentUser,
      accessToken: 'seed-token',
      tokenType: 'bearer',
    );
  }

  @override
  Future<SessionUser> fetchCurrentUser(String token) async => currentUser;

  @override
  Future<List<CourseSummary>> fetchCourses(String token) async => courses;

  @override
  Future<List<StudentSummary>> fetchStudents(
    String token, {
    required int courseId,
  }) async {
    return studentsByCourse[courseId] ?? const <StudentSummary>[];
  }

  @override
  Future<List<CourseAttendanceItem>> fetchCourseAttendance(
    String token, {
    required int courseId,
    required DateTime date,
  }) async {
    final students = studentsByCourse[courseId] ?? const <StudentSummary>[];
    final savedStatuses =
        savedStatusesByCourseDate[_courseDateKey(courseId, date)] ??
        const <int, AttendanceMark>{};

    return students
        .map(
          (student) => CourseAttendanceItem(
            studentId: student.id,
            studentName: student.name,
            usn: student.usn,
            department: student.department,
            status: savedStatuses[student.id] ?? AttendanceMark.present,
          ),
        )
        .toList();
  }

  @override
  Future<List<AttendanceSheetEntry>> fetchAttendanceSheet(
    String token, {
    required int courseId,
    required DateTime date,
  }) async {
    final attendance = await fetchCourseAttendance(
      token,
      courseId: courseId,
      date: date,
    );

    return attendance
        .map(
          (entry) => AttendanceSheetEntry(
            studentId: entry.studentId,
            studentName: entry.studentName,
            usn: entry.usn,
            department: entry.department,
            status: entry.status,
          ),
        )
        .toList();
  }

  @override
  Future<void> markAttendance(
    String token,
    MarkAttendanceRequest request,
  ) async {
    if (saveError != null) {
      throw saveError!;
    }

    markedRequests.add(request);
    savedStatusesByCourseDate[_courseDateKey(request.courseId, request.date)] =
        {for (final record in request.records) record.studentId: record.status};
  }

  Map<int, AttendanceMark> savedStatusesFor(int courseId, DateTime date) {
    return savedStatusesByCourseDate[_courseDateKey(courseId, date)] ??
        const <int, AttendanceMark>{};
  }

  String _courseDateKey(int courseId, DateTime date) {
    return '$courseId:${formatApiDate(date)}';
  }

  @override
  Future<CollegeAnalytics> fetchCollegeAnalytics(String token) async {
    return collegeAnalytics;
  }

  @override
  Future<List<DepartmentAnalytics>> fetchDepartmentAnalytics(
    String token,
  ) async {
    return departmentAnalytics;
  }

  @override
  Future<List<AttendanceReportItem>> fetchAttendanceReports(
    String token,
  ) async {
    return reports;
  }

  @override
  Future<StudentAttendanceSummary> fetchStudentAttendance(
    String token, {
    required int studentId,
  }) async {
    return studentAttendance;
  }
}

class MemorySessionStore implements SessionStore {
  StoredSession? storedSession;

  @override
  Future<StoredSession?> read() async => storedSession;

  @override
  Future<void> save({required String token, required SessionUser user}) async {
    storedSession = StoredSession(token: token, user: user);
  }

  @override
  Future<void> clear() async {
    storedSession = null;
  }
}

class FakeGoogleAuthClient implements GoogleAuthClient {
  FakeGoogleAuthClient({
    this.identity = const GoogleIdentity(
      email: 'lecturer@college.edu',
      idToken: 'google-id-token',
    ),
    this.error,
  });

  GoogleIdentity? identity;
  Object? error;
  int signOutCalls = 0;

  @override
  Future<GoogleIdentity?> signIn() async {
    if (error != null) {
      throw error!;
    }
    return identity;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }
}

SessionController buildAuthenticatedSessionController({required AmsApi api}) {
  final controller = SessionController(
    api: api,
    store: MemorySessionStore(),
    googleAuth: FakeGoogleAuthClient(),
  );
  controller.user = const SessionUser(
    userId: 21,
    email: 'lecturer@college.edu',
    role: 'lecturer',
    name: 'Prof. Samuel Reed',
    collegeId: 1,
  );
  controller.token = 'seed-token';
  controller.status = SessionStatus.authenticated;
  return controller;
}
