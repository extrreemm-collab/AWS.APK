import 'dart:convert';

import 'package:ams_frontend/models.dart';
import 'package:ams_frontend/services/api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AmsApiService.fetchGoogleClientId', () {
    test('returns the configured public Google client ID', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/auth/google/config');
        return http.Response(
          jsonEncode({
            'client_id':
                '272510364011-nhod5n2eufrookl0d18pnmsc0ka40d6o.apps.googleusercontent.com',
          }),
          200,
        );
      });

      final api = AmsApiService(baseUrl: 'http://example.test', client: client);

      final clientId = await api.fetchGoogleClientId();

      expect(
        clientId,
        '272510364011-nhod5n2eufrookl0d18pnmsc0ka40d6o.apps.googleusercontent.com',
      );
    });
  });

  group('AmsApiService.authenticateWithGoogle', () {
    test('sends the selected role with the Google token', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/auth/google');
        expect(jsonDecode(request.body), {
          'id_token': 'google-id-token',
          'role': 'lecturer',
        });
        return http.Response(
          jsonEncode({
            'user_id': 21,
            'email': 'lecturer@college.edu',
            'role': 'lecturer',
            'name': 'Prof. Samuel Reed',
            'college_id': 1,
            'student_id': null,
            'access_token': 'lecturer-token',
            'token_type': 'bearer',
          }),
          200,
        );
      });

      final api = AmsApiService(baseUrl: 'http://example.test', client: client);

      final response = await api.authenticateWithGoogle(
        idToken: 'google-id-token',
        role: 'lecturer',
      );

      expect(response.user.role, 'lecturer');
      expect(response.accessToken, 'lecturer-token');
    });
  });

  group('AmsApiService.fetchAttendanceSheet', () {
    test(
      'loads the course roster and overlays saved statuses for the date',
      () async {
        final client = MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer seed-token');

          if (request.url.path == '/students') {
            expect(request.url.queryParameters, {'course_id': '5'});
            return http.Response(
              jsonEncode([
                {
                  'id': 1,
                  'name': 'Aisha Khan',
                  'usn': '4AL22CS001',
                  'department': 'Computer Science',
                },
                {
                  'id': 2,
                  'name': 'Maya Patel',
                  'usn': '4AL22CS002',
                  'department': 'Computer Science',
                },
              ]),
              200,
            );
          }

          if (request.url.path == '/attendance/course/5') {
            expect(request.url.queryParameters, {'date': '2026-03-14'});
            return http.Response(
              jsonEncode([
                {
                  'student_id': 2,
                  'student_name': 'Maya Patel',
                  'usn': '4AL22CS002',
                  'department': 'Computer Science',
                  'status': 'absent',
                },
              ]),
              200,
            );
          }

          throw StateError(
            'Unexpected request: ${request.method} ${request.url}',
          );
        });

        final api = AmsApiService(
          baseUrl: 'http://example.test',
          client: client,
        );

        final entries = await api.fetchAttendanceSheet(
          'seed-token',
          courseId: 5,
          date: DateTime(2026, 3, 14),
        );

        expect(entries, hasLength(2));
        expect(entries[0].studentName, 'Aisha Khan');
        expect(entries[0].status, AttendanceMark.present);
        expect(entries[1].studentName, 'Maya Patel');
        expect(entries[1].status, AttendanceMark.absent);
      },
    );
  });
}
