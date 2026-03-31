import 'package:ams_frontend/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthResponse', () {
    test('parses the top-level auth payload into a session user', () {
      final response = AuthResponse.fromJson({
        'user_id': 11,
        'email': 'lecturer@college.edu',
        'role': 'lecturer',
        'name': 'Prof. Samuel Reed',
        'college_id': 3,
        'student_id': null,
        'access_token': 'token-123',
        'token_type': 'bearer',
      });

      expect(response.accessToken, 'token-123');
      expect(response.tokenType, 'bearer');
      expect(response.user.userId, 11);
      expect(response.user.email, 'lecturer@college.edu');
      expect(response.user.role, 'lecturer');
      expect(response.user.name, 'Prof. Samuel Reed');
      expect(response.user.collegeId, 3);
      expect(response.user.studentId, isNull);
    });
  });

  group('MarkAttendanceRequest', () {
    test('serializes explicit attendance status records', () {
      final request = MarkAttendanceRequest(
        courseId: 9,
        date: DateTime(2026, 3, 14),
        records: const [
          AttendanceStatus(studentId: 7, status: AttendanceMark.absent),
        ],
      );

      expect(request.toJson(), {
        'course_id': 9,
        'date': '2026-03-14',
        'records': [
          {'student_id': 7, 'status': 'absent'},
        ],
      });
    });

    test('builds attendance records from visible sheet entries', () {
      final request = MarkAttendanceRequest.fromEntries(
        courseId: 4,
        date: DateTime(2026, 3, 14),
        entries: const [
          AttendanceSheetEntry(
            studentId: 1,
            studentName: 'Aisha Khan',
            usn: '4AL22CS001',
            department: 'Computer Science',
            status: AttendanceMark.present,
          ),
          AttendanceSheetEntry(
            studentId: 2,
            studentName: 'Maya Patel',
            usn: '4AL22CS002',
            department: 'Computer Science',
            status: AttendanceMark.absent,
          ),
        ],
      );

      expect(request.toJson(), {
        'course_id': 4,
        'date': '2026-03-14',
        'records': [
          {'student_id': 1, 'status': 'present'},
          {'student_id': 2, 'status': 'absent'},
        ],
      });
    });
  });
}
