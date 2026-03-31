import 'package:ams_frontend/models.dart';
import 'package:ams_frontend/screens/attendance_screen.dart';
import 'package:ams_frontend/services/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/fakes.dart';

void main() {
  const course = CourseSummary(
    id: 5,
    courseName: 'Cloud Foundations',
    lecturerId: 21,
    lecturerName: 'Prof. Samuel Reed',
    studentCount: 2,
  );

  const enrolledStudents = <StudentSummary>[
    StudentSummary(
      id: 1,
      name: 'Aisha Khan',
      usn: '4AL22CS001',
      department: 'Computer Science',
    ),
    StudentSummary(
      id: 2,
      name: 'Maya Patel',
      usn: '4AL22CS002',
      department: 'Computer Science',
    ),
  ];

  testWidgets(
    'loads the roster, saves attendance, and reloads saved statuses',
    (tester) async {
      final api = FakeAmsApi(studentsByCourse: {course.id: enrolledStudents});
      final controller = buildAuthenticatedSessionController(api: api);

      await tester.pumpWidget(
        MaterialApp(
          home: AttendanceScreen(sessionController: controller, course: course),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Aisha Khan'), findsOneWidget);
      expect(find.text('Maya Patel'), findsOneWidget);
      expect(find.text('2 present'), findsOneWidget);

      await tester.tap(find.text('Mark all absent'));
      await tester.pumpAndSettle();

      expect(find.text('0 present'), findsOneWidget);

      await tester.tap(find.text('Save Attendance'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(api.markedRequests, hasLength(1));
      expect(
        api.savedStatusesFor(course.id, api.markedRequests.single.date),
        <int, AttendanceMark>{
          1: AttendanceMark.absent,
          2: AttendanceMark.absent,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AttendanceScreen(sessionController: controller, course: course),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 present'), findsOneWidget);
    },
  );

  testWidgets('shows an explicit inline error when save fails', (tester) async {
    final api = FakeAmsApi(
      studentsByCourse: {course.id: enrolledStudents},
      saveError: const ApiException(
        message: 'Could not save attendance right now.',
      ),
    );
    final controller = buildAuthenticatedSessionController(api: api);

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceScreen(sessionController: controller, course: course),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Attendance'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Attendance was not saved'), findsOneWidget);
    expect(find.text('Could not save attendance right now.'), findsWidgets);
  });
}
