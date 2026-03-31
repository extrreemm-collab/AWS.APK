import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api.dart';
import '../state/session_controller.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  Future<StudentAttendanceSummary>? _summaryFuture;

  AmsApi get _api => widget.sessionController.api;

  @override
  void initState() {
    super.initState();
    if (widget.sessionController.user?.studentId != null) {
      _summaryFuture = _loadSummary();
    }
  }

  Future<StudentAttendanceSummary> _loadSummary() async {
    try {
      return await _api.fetchStudentAttendance(
        widget.sessionController.requireToken,
        studentId: widget.sessionController.user!.studentId!,
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget.sessionController.handleUnauthorized();
        return const StudentAttendanceSummary(
          studentId: 0,
          studentName: '',
          attendancePercentage: 0,
          presentClasses: 0,
          totalClasses: 0,
          subjectBreakdown: <SubjectAttendanceSummary>[],
          history: <AttendanceHistoryItem>[],
        );
      }
      rethrow;
    }
  }

  Future<void> _refreshSummary() async {
    if (widget.sessionController.user?.studentId == null) {
      return;
    }

    final nextFuture = _loadSummary();
    setState(() {
      _summaryFuture = nextFuture;
    });
    await nextFuture;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.sessionController.user;
    final studentId = user?.studentId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
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
            colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: studentId == null
              ? const _StudentLinkState()
              : FutureBuilder<StudentAttendanceSummary>(
                  future: _summaryFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return _StudentErrorState(
                        message: snapshot.error.toString(),
                        onRetry: _refreshSummary,
                      );
                    }

                    final summary =
                        snapshot.data ??
                        const StudentAttendanceSummary(
                          studentId: 0,
                          studentName: '',
                          attendancePercentage: 0,
                          presentClasses: 0,
                          totalClasses: 0,
                          subjectBreakdown: <SubjectAttendanceSummary>[],
                          history: <AttendanceHistoryItem>[],
                        );

                    return RefreshIndicator(
                      onRefresh: _refreshSummary,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, ${summary.studentName.isEmpty ? user?.name ?? 'Student' : summary.studentName}',
                                  style: Theme.of(context).textTheme.headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Track your attendance percentage and subject-wise progress.',
                                  style: TextStyle(
                                    color: Color(0xFFDBEAFE),
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  '${summary.attendancePercentage.toStringAsFixed(1)}%',
                                  style: Theme.of(context).textTheme.displaySmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${summary.presentClasses} present out of ${summary.totalClasses} classes',
                                  style: const TextStyle(
                                    color: Color(0xFFDBEAFE),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Subject Breakdown',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          if (summary.subjectBreakdown.isEmpty)
                            const _StudentEmptyState(
                              title: 'No subject attendance yet',
                              message:
                                  'Subject-wise attendance appears after classes are marked.',
                            )
                          else
                            ...summary.subjectBreakdown.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _SubjectCard(item: item),
                              ),
                            ),
                          const SizedBox(height: 22),
                          Text(
                            'Recent Attendance',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          if (summary.history.isEmpty)
                            const _StudentEmptyState(
                              title: 'No attendance history yet',
                              message:
                                  'Your recent attendance entries will appear here after lecturers begin marking classes.',
                            )
                          else
                            ...summary.history.take(5).map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _HistoryCard(item: item),
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

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.item});

  final SubjectAttendanceSummary item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.courseName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: item.totalClasses == 0 ? 0 : item.attendancePercentage / 100,
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: const Color(0xFFE2E8F0),
            ),
            const SizedBox(height: 10),
            Text(
              '${item.attendancePercentage.toStringAsFixed(1)}%  •  ${item.presentClasses}/${item.totalClasses} classes',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final AttendanceHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        title: Text(
          item.courseName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(formatter.format(item.date)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: item.status == AttendanceMark.present
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            item.status.label,
            style: TextStyle(
              color: item.status == AttendanceMark.present
                  ? const Color(0xFF166534)
                  : const Color(0xFF991B1B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentLinkState extends StatelessWidget {
  const _StudentLinkState();

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
                  Icons.link_off_rounded,
                  size: 48,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(height: 14),
                Text(
                  'Student record not linked',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your Google account is authenticated, but your student record is missing from the attendance roster. Please contact the college administrator.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentEmptyState extends StatelessWidget {
  const _StudentEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.fact_check_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _StudentErrorState extends StatelessWidget {
  const _StudentErrorState({required this.message, required this.onRetry});

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
                  'Could not load your attendance',
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
