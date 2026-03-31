import 'package:ams_frontend/models.dart';
import 'package:ams_frontend/screens/lecturer_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/fakes.dart';

void main() {
  testWidgets('renders assigned courses with enrolled student counts', (
    tester,
  ) async {
    final api = FakeAmsApi(
      courses: const [
        CourseSummary(
          id: 7,
          courseName: 'Cloud Foundations',
          lecturerId: 21,
          lecturerName: 'Prof. Samuel Reed',
          studentCount: 3,
        ),
        CourseSummary(
          id: 3,
          courseName: 'Data Structures',
          lecturerId: 21,
          lecturerName: 'Prof. Samuel Reed',
          studentCount: 2,
        ),
      ],
    );
    final controller = buildAuthenticatedSessionController(api: api);

    await tester.pumpWidget(
      MaterialApp(home: LecturerHomeScreen(sessionController: controller)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Assigned Courses'), findsOneWidget);
    expect(find.text('Cloud Foundations'), findsOneWidget);
    expect(find.text('Data Structures'), findsOneWidget);
    expect(find.text('3 enrolled students'), findsOneWidget);
    expect(find.text('2 enrolled students'), findsOneWidget);
  });
}
