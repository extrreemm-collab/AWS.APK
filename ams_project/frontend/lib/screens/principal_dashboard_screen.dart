import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import '../state/session_controller.dart';

class PrincipalDashboardScreen extends StatefulWidget {
  const PrincipalDashboardScreen({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<PrincipalDashboardScreen> createState() =>
      _PrincipalDashboardScreenState();
}

class _PrincipalDashboardScreenState extends State<PrincipalDashboardScreen> {
  late Future<_PrincipalDashboardData> _dashboardFuture;

  AmsApi get _api => widget.sessionController.api;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<_PrincipalDashboardData> _loadDashboard() async {
    try {
      final token = widget.sessionController.requireToken;
      final analytics = await _api.fetchCollegeAnalytics(token);
      final reports = await _api.fetchAttendanceReports(token);
      return _PrincipalDashboardData(analytics: analytics, reports: reports);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget.sessionController.handleUnauthorized();
        return const _PrincipalDashboardData.empty();
      }
      rethrow;
    }
  }

  Future<void> _refreshDashboard() async {
    final nextFuture = _loadDashboard();
    setState(() {
      _dashboardFuture = nextFuture;
    });
    await nextFuture;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.sessionController.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Principal Dashboard'),
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
            colors: [Color(0xFFE0F2F1), Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<_PrincipalDashboardData>(
            future: _dashboardFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _DashboardErrorState(
                  title: 'Could not load college analytics',
                  message: snapshot.error.toString(),
                  onRetry: _refreshDashboard,
                );
              }

              final data = snapshot.data ?? const _PrincipalDashboardData.empty();
              final analytics = data.analytics;
              final reports = data.reports;

              return RefreshIndicator(
                onRefresh: _refreshDashboard,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    _DashboardHero(
                      title: 'Welcome, ${user?.name ?? 'Principal'}',
                      subtitle:
                          'College-wide attendance visibility across departments and courses.',
                      chips: [
                        _HeroChip(
                          icon: Icons.groups_rounded,
                          label: '${analytics.totalStudents} students',
                        ),
                        _HeroChip(
                          icon: Icons.analytics_outlined,
                          label:
                              '${analytics.attendancePercentage.toStringAsFixed(1)}% attendance',
                        ),
                        _HeroChip(
                          icon: Icons.apartment_rounded,
                          label: '${analytics.departments.length} departments',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Department Snapshot',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (analytics.departments.isEmpty)
                      const _EmptyState(
                        title: 'No departments available',
                        message:
                            'Department attendance analytics will appear here when student and attendance data are added.',
                      )
                    else
                      ...analytics.departments.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DepartmentCard(item: item),
                        ),
                      ),
                    const SizedBox(height: 22),
                    Text(
                      'Course Reports',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (reports.isEmpty)
                      const _EmptyState(
                        title: 'No attendance reports yet',
                        message:
                            'Course attendance summaries will appear after lecturers start marking attendance.',
                      )
                    else
                      ...reports.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ReportCard(item: item),
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

class _PrincipalDashboardData {
  const _PrincipalDashboardData({
    required this.analytics,
    required this.reports,
  });

  const _PrincipalDashboardData.empty()
    : analytics = const CollegeAnalytics(
        totalStudents: 0,
        totalRecords: 0,
        presentCount: 0,
        attendancePercentage: 0,
        departments: <DepartmentAnalytics>[],
      ),
      reports = const <AttendanceReportItem>[];

  final CollegeAnalytics analytics;
  final List<AttendanceReportItem> reports;
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.title,
    required this.subtitle,
    required this.chips,
  });

  final String title;
  final String subtitle;
  final List<_HeroChip> chips;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFE0F2FE),
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: chips,
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

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
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.item});

  final DepartmentAnalytics item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.department,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${item.totalStudents} students  •  ${item.attendancePercentage.toStringAsFixed(1)}% attendance',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.item});

  final AttendanceReportItem item;

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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${item.department}  •  ${item.lecturerName}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Text(
              '${item.attendancePercentage.toStringAsFixed(1)}% attendance across ${item.totalClasses} classes',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

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
              Icons.dashboard_customize_outlined,
              size: 46,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
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

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({
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
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
