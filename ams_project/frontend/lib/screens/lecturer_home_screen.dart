import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api.dart';
import '../state/session_controller.dart';
import 'attendance_screen.dart';

class LecturerHomeScreen extends StatefulWidget {
  const LecturerHomeScreen({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<LecturerHomeScreen> createState() => _LecturerHomeScreenState();
}

class _LecturerHomeScreenState extends State<LecturerHomeScreen> {
  late Future<List<CourseSummary>> _coursesFuture;

  AmsApi get _api => widget.sessionController.api;

  @override
  void initState() {
    super.initState();
    _coursesFuture = _loadCourses();
  }

  Future<List<CourseSummary>> _loadCourses() async {
    try {
      return await _api.fetchCourses(widget.sessionController.requireToken);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget.sessionController.handleUnauthorized();
        return const [];
      }
      rethrow;
    }
  }

  Future<void> _refreshCourses() async {
    final nextFuture = _loadCourses();
    setState(() {
      _coursesFuture = nextFuture;
    });
    await nextFuture;
  }

  Future<void> _openCourse(CourseSummary course) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AttendanceScreen(
          sessionController: widget.sessionController,
          course: course,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _refreshCourses();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.sessionController.user;
    final formatter = DateFormat('EEEE, MMM d');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturer Dashboard'),
        actions: [
          IconButton(
            onPressed: widget.sessionController.logout,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F2F1), Color(0xFFF3EDE2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<CourseSummary>>(
            future: _coursesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _ErrorState(
                  title: 'Could not load courses',
                  message: snapshot.error.toString(),
                  onRetry: _refreshCourses,
                );
              }

              final courses = snapshot.data ?? const <CourseSummary>[];
              return RefreshIndicator(
                onRefresh: _refreshCourses,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, ${user?.name ?? 'Lecturer'}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            formatter.format(DateTime.now()),
                            style: const TextStyle(
                              color: Color(0xFFD1FAE5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _SummaryChip(
                                icon: Icons.menu_book_rounded,
                                label: '${courses.length} courses',
                              ),
                              _SummaryChip(
                                icon: Icons.school_rounded,
                                label: user?.email ?? 'College account',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Assigned Courses',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (courses.isEmpty)
                      const _EmptyCoursesState()
                    else
                      ...courses.map(
                        (course) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _CourseCard(
                            course: course,
                            onTap: () => _openCourse(course),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});

  final CourseSummary course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFFCCFBF1),
                ),
                child: const Icon(
                  Icons.co_present_rounded,
                  color: Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.courseName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${course.studentCount} enrolled students',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCoursesState extends StatelessWidget {
  const _EmptyCoursesState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            Text(
              'No courses assigned yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Courses assigned by your HOD or principal will appear here for attendance marking.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
