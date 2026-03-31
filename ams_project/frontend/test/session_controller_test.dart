import 'package:ams_frontend/models.dart';
import 'package:ams_frontend/services/api.dart';
import 'package:ams_frontend/services/google_auth.dart';
import 'package:ams_frontend/services/session_store.dart';
import 'package:ams_frontend/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionController', () {
    test(
      'stores a lecturer Google sign-in and marks the session authenticated',
      () async {
        final api = _FakeAmsApi(
          authResponse: AuthResponse(
            user: const SessionUser(
              userId: 21,
              email: 'lecturer@college.edu',
              role: 'lecturer',
              name: 'Prof. Samuel Reed',
              collegeId: 1,
            ),
            accessToken: 'lecturer-token',
            tokenType: 'bearer',
          ),
        );
        final store = _MemorySessionStore();
        final controller = SessionController(
          api: api,
          store: store,
          googleAuth: _FakeGoogleAuthClient(),
        );
        controller.selectRole(LoginRole.lecturer);

        final success = await controller.signInWithGoogle();

        expect(success, isTrue);
        expect(controller.status, SessionStatus.authenticated);
        expect(controller.errorMessage, isNull);
        expect(api.receivedGoogleRole, 'lecturer');
        expect(store.savedToken, 'lecturer-token');
        expect(store.savedUser?.role, 'lecturer');
        expect(controller.user?.name, 'Prof. Samuel Reed');
      },
    );

    test('accepts supported non-lecturer roles after Google sign-in', () async {
      final controller = SessionController(
        api: _FakeAmsApi(
          authResponse: AuthResponse(
            user: const SessionUser(
              userId: 5,
              email: 'hod.cs@college.edu',
              role: 'hod',
              name: 'Dr. Helen Carter',
              collegeId: 1,
            ),
            accessToken: 'hod-token',
            tokenType: 'bearer',
          ),
        ),
        store: _MemorySessionStore(),
        googleAuth: _FakeGoogleAuthClient(
          identity: const GoogleIdentity(
            email: 'hod.cs@college.edu',
            idToken: 'hod-google-id-token',
          ),
        ),
      );
      controller.selectRole(LoginRole.hod);

      final success = await controller.signInWithGoogle();

      expect(success, isTrue);
      expect(controller.status, SessionStatus.authenticated);
      expect(controller.user?.role, 'hod');
      expect((controller.api as _FakeAmsApi).receivedGoogleRole, 'hod');
      expect(controller.errorMessage, isNull);
    });

    test('requires a selected role before Google sign-in', () async {
      final controller = SessionController(
        api: _FakeAmsApi(),
        store: _MemorySessionStore(),
        googleAuth: _FakeGoogleAuthClient(),
      );

      final success = await controller.signInWithGoogle();

      expect(success, isFalse);
      expect(
        controller.errorMessage,
        'Select your role before continuing with Google.',
      );
    });

    test(
      'shows the backend error when the Google account is not registered',
      () async {
        final googleAuth = _FakeGoogleAuthClient();
        final controller = SessionController(
          api: _FakeAmsApi(
            authError: const ApiException(
              message:
                  'Your account is not registered as a Lecturer. Contact administrator.',
              statusCode: 403,
            ),
          ),
          store: _MemorySessionStore(),
          googleAuth: googleAuth,
        );
        controller.selectRole(LoginRole.lecturer);

        await controller.initialize();
        final success = await controller.signInWithGoogle();

        expect(success, isFalse);
        expect(controller.status, SessionStatus.signedOut);
        expect(
          controller.errorMessage,
          'Your account is not registered as a Lecturer. Contact administrator.',
        );
        expect(googleAuth.signOutCalls, 1);
      },
    );

    test('restores and refreshes a stored session through /auth/me', () async {
      final storedUser = const SessionUser(
        userId: 21,
        email: 'lecturer@college.edu',
        role: 'lecturer',
        name: 'Old Name',
        collegeId: 1,
      );
      final refreshedUser = const SessionUser(
        userId: 21,
        email: 'lecturer@college.edu',
        role: 'lecturer',
        name: 'Prof. Samuel Reed',
        collegeId: 1,
      );
      final store = _MemorySessionStore(
        storedSession: StoredSession(
          token: 'persisted-token',
          user: storedUser,
        ),
      );
      final controller = SessionController(
        api: _FakeAmsApi(currentUserResponse: refreshedUser),
        store: store,
        googleAuth: _FakeGoogleAuthClient(),
      );

      await controller.initialize();

      expect(controller.status, SessionStatus.authenticated);
      expect(controller.user?.name, 'Prof. Samuel Reed');
      expect(store.savedToken, 'persisted-token');
      expect(store.savedUser?.name, 'Prof. Samuel Reed');
      expect(store.clearCalls, 0);
    });

    test(
      'clears the stored session when /auth/me returns unauthorized',
      () async {
        final store = _MemorySessionStore(
          storedSession: StoredSession(
            token: 'expired-token',
            user: const SessionUser(
              userId: 21,
              email: 'lecturer@college.edu',
              role: 'lecturer',
              name: 'Prof. Samuel Reed',
              collegeId: 1,
            ),
          ),
        );
        final controller = SessionController(
          api: _FakeAmsApi(
            currentUserError: const ApiException(
              message: 'Could not validate credentials',
              statusCode: 401,
            ),
          ),
          store: store,
          googleAuth: _FakeGoogleAuthClient(),
        );

        await controller.initialize();

        expect(controller.status, SessionStatus.signedOut);
        expect(controller.token, isNull);
        expect(controller.user, isNull);
        expect(
          controller.errorMessage,
          'Your session expired. Please sign in again.',
        );
        expect(store.clearCalls, 1);
      },
    );
  });
}

class _FakeAmsApi implements AmsApi {
  _FakeAmsApi({
    this.authResponse,
    this.authError,
    this.currentUserResponse,
    this.currentUserError,
  });

  final AuthResponse? authResponse;
  final Object? authError;
  final SessionUser? currentUserResponse;
  final Object? currentUserError;
  String? receivedGoogleRole;

  @override
  String get baseUrl => 'http://example.test';

  @override
  Future<String?> fetchGoogleClientId() async => null;

  @override
  Future<AuthResponse> authenticateWithGoogle({
    required String idToken,
    required String role,
  }) async {
    receivedGoogleRole = role;
    if (authError != null) {
      throw authError!;
    }
    return authResponse!;
  }

  @override
  Future<SessionUser> fetchCurrentUser(String token) async {
    if (currentUserError != null) {
      throw currentUserError!;
    }
    return currentUserResponse!;
  }

  @override
  Future<List<CourseSummary>> fetchCourses(String token) {
    throw UnimplementedError();
  }

  @override
  Future<List<StudentSummary>> fetchStudents(
    String token, {
    required int courseId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<CourseAttendanceItem>> fetchCourseAttendance(
    String token, {
    required int courseId,
    required DateTime date,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<AttendanceSheetEntry>> fetchAttendanceSheet(
    String token, {
    required int courseId,
    required DateTime date,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> markAttendance(String token, MarkAttendanceRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<CollegeAnalytics> fetchCollegeAnalytics(String token) {
    throw UnimplementedError();
  }

  @override
  Future<List<DepartmentAnalytics>> fetchDepartmentAnalytics(String token) {
    throw UnimplementedError();
  }

  @override
  Future<List<AttendanceReportItem>> fetchAttendanceReports(String token) {
    throw UnimplementedError();
  }

  @override
  Future<StudentAttendanceSummary> fetchStudentAttendance(
    String token, {
    required int studentId,
  }) {
    throw UnimplementedError();
  }
}

class _FakeGoogleAuthClient implements GoogleAuthClient {
  _FakeGoogleAuthClient({
    this.identity = const GoogleIdentity(
      email: 'lecturer@college.edu',
      idToken: 'google-id-token',
    ),
  });

  GoogleIdentity? identity;
  int signOutCalls = 0;

  @override
  Future<GoogleIdentity?> signIn() async {
    return identity;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }
}

class _MemorySessionStore implements SessionStore {
  _MemorySessionStore({this.storedSession});

  StoredSession? storedSession;
  String? savedToken;
  SessionUser? savedUser;
  int clearCalls = 0;

  @override
  Future<StoredSession?> read() async => storedSession;

  @override
  Future<void> save({required String token, required SessionUser user}) async {
    savedToken = token;
    savedUser = user;
    storedSession = StoredSession(token: token, user: user);
  }

  @override
  Future<void> clear() async {
    clearCalls += 1;
    storedSession = null;
    savedToken = null;
    savedUser = null;
  }
}
