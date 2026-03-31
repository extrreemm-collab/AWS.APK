import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';

abstract class AmsApi {
  String get baseUrl;

  Future<String?> fetchGoogleClientId();

  Future<AuthResponse> authenticateWithGoogle({
    required String idToken,
    required String role,
  });

  Future<SessionUser> fetchCurrentUser(String token);

  Future<List<CourseSummary>> fetchCourses(String token);

  Future<List<StudentSummary>> fetchStudents(
    String token, {
    required int courseId,
  });

  Future<List<CourseAttendanceItem>> fetchCourseAttendance(
    String token, {
    required int courseId,
    required DateTime date,
  });

  Future<List<AttendanceSheetEntry>> fetchAttendanceSheet(
    String token, {
    required int courseId,
    required DateTime date,
  });

  Future<void> markAttendance(String token, MarkAttendanceRequest request);

  Future<CollegeAnalytics> fetchCollegeAnalytics(String token);

  Future<List<DepartmentAnalytics>> fetchDepartmentAnalytics(String token);

  Future<List<AttendanceReportItem>> fetchAttendanceReports(String token);

  Future<StudentAttendanceSummary> fetchStudentAttendance(
    String token, {
    required int studentId,
  });
}

class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class AmsApiService implements AmsApi {
  AmsApiService({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl,
      _client = client ?? http.Client();

  factory AmsApiService.fromEnvironment() {
    return AmsApiService(
      baseUrl: const String.fromEnvironment(
        'AMS_API_BASE_URL',
        defaultValue: 'http://10.0.2.2:8000',
      ),
    );
  }

  final String _baseUrl;
  final http.Client _client;

  @override
  String get baseUrl => _baseUrl;

  String get _normalizedBaseUrl => _baseUrl.endsWith('/')
      ? _baseUrl.substring(0, _baseUrl.length - 1)
      : _baseUrl;

  @override
  Future<String?> fetchGoogleClientId() async {
    final response = await _getJson('/auth/google/config');
    final clientId = response['client_id'];
    if (clientId is! String) {
      return null;
    }
    final trimmed = clientId.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<AuthResponse> authenticateWithGoogle({
    required String idToken,
    required String role,
  }) async {
    final response = await _postJson(
      '/auth/google',
      body: {'id_token': idToken, 'role': role},
    );
    return AuthResponse.fromJson(response);
  }

  @override
  Future<SessionUser> fetchCurrentUser(String token) async {
    final response = await _getJson('/auth/me', token: token);
    return SessionUser.fromJson(response);
  }

  @override
  Future<List<CourseSummary>> fetchCourses(String token) async {
    final response = await _getJsonList('/courses', token: token);
    return response.map(CourseSummary.fromJson).toList()
      ..sort((left, right) => left.courseName.compareTo(right.courseName));
  }

  @override
  Future<List<StudentSummary>> fetchStudents(
    String token, {
    required int courseId,
  }) async {
    final response = await _getJsonList(
      '/students',
      token: token,
      queryParameters: {'course_id': '$courseId'},
    );

    return response.map(StudentSummary.fromJson).toList()
      ..sort((left, right) => left.name.compareTo(right.name));
  }

  @override
  Future<List<CourseAttendanceItem>> fetchCourseAttendance(
    String token, {
    required int courseId,
    required DateTime date,
  }) async {
    final response = await _getJsonList(
      '/attendance/course/$courseId',
      token: token,
      queryParameters: {'date': formatApiDate(date)},
    );

    return response.map(CourseAttendanceItem.fromJson).toList();
  }

  @override
  Future<List<AttendanceSheetEntry>> fetchAttendanceSheet(
    String token, {
    required int courseId,
    required DateTime date,
  }) async {
    final students = await fetchStudents(token, courseId: courseId);
    final attendance = await fetchCourseAttendance(
      token,
      courseId: courseId,
      date: date,
    );
    final statusByStudentId = {
      for (final item in attendance) item.studentId: item.status,
    };

    return students
        .map(
          (student) => AttendanceSheetEntry(
            studentId: student.id,
            studentName: student.name,
            usn: student.usn,
            department: student.department,
            status: statusByStudentId[student.id] ?? AttendanceMark.present,
          ),
        )
        .toList();
  }

  @override
  Future<void> markAttendance(
    String token,
    MarkAttendanceRequest request,
  ) async {
    await _postJson('/attendance/mark', token: token, body: request.toJson());
  }

  @override
  Future<CollegeAnalytics> fetchCollegeAnalytics(String token) async {
    final response = await _getJson('/analytics/college', token: token);
    return CollegeAnalytics.fromJson(response);
  }

  @override
  Future<List<DepartmentAnalytics>> fetchDepartmentAnalytics(
    String token,
  ) async {
    final response = await _getJsonList('/analytics/departments', token: token);
    return response.map(DepartmentAnalytics.fromJson).toList();
  }

  @override
  Future<List<AttendanceReportItem>> fetchAttendanceReports(
    String token,
  ) async {
    final response = await _getJsonList('/reports/attendance', token: token);
    return response.map(AttendanceReportItem.fromJson).toList();
  }

  @override
  Future<StudentAttendanceSummary> fetchStudentAttendance(
    String token, {
    required int studentId,
  }) async {
    final response = await _getJson(
      '/attendance/student/$studentId',
      token: token,
    );
    return StudentAttendanceSummary.fromJson(response);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    String? token,
    Map<String, String>? queryParameters,
  }) async {
    final response = await _send(
      method: 'GET',
      path: path,
      token: token,
      queryParameters: queryParameters,
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Expected a JSON object from the server.',
      );
    }
    return response;
  }

  Future<List<Map<String, dynamic>>> _getJsonList(
    String path, {
    String? token,
    Map<String, String>? queryParameters,
  }) async {
    final response = await _send(
      method: 'GET',
      path: path,
      token: token,
      queryParameters: queryParameters,
    );

    if (response is! List) {
      throw const ApiException(
        message: 'Expected a JSON list from the server.',
      );
    }

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    String? token,
    required Map<String, dynamic> body,
  }) async {
    final response = await _send(
      method: 'POST',
      path: path,
      token: token,
      body: body,
    );

    if (response == null) {
      return const {};
    }
    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'Expected a JSON object from the server.',
      );
    }
    return response;
  }

  Future<dynamic> _send({
    required String method,
    required String path,
    String? token,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse(
      '$_normalizedBaseUrl$path',
    ).replace(queryParameters: queryParameters);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    late http.Response response;
    try {
      response = switch (method) {
        'GET' => await _client.get(uri, headers: headers),
        'POST' => await _client.post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
        _ => throw StateError('Unsupported HTTP method: $method'),
      };
    } catch (_) {
      throw ApiException(
        message: 'Could not reach AMS backend at $_normalizedBaseUrl.',
      );
    }

    dynamic decodedBody;
    if (response.body.trim().isNotEmpty) {
      decodedBody = jsonDecode(response.body);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message: _extractErrorMessage(decodedBody, response.statusCode),
        statusCode: response.statusCode,
      );
    }

    return decodedBody;
  }

  String _extractErrorMessage(dynamic payload, int statusCode) {
    if (payload is Map<String, dynamic>) {
      final detail = payload['detail'] ?? payload['message'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
    }

    return switch (statusCode) {
      401 => 'Your session is no longer valid. Please sign in again.',
      403 => 'You do not have access to this action.',
      404 => 'The requested resource was not found.',
      500 => 'The server is missing a required Google Sign-In configuration.',
      _ => 'The server could not complete the request.',
    };
  }
}
