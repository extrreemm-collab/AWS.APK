import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import '../state/session_controller.dart';

class HodDashboardScreen extends StatefulWidget {
  const HodDashboardScreen({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<HodDashboardScreen> createState() => _HodDashboardScreenState();
}

class _HodDashboardScreenState extends State<HodDashboardScreen> {
  late Future<List<DepartmentAnalytics>> _analyticsFuture;

  AmsApi get _api => widget.sessionController.api;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _loadAnalytics();
  }

  Future<List<DepartmentAnalytics>> _loadAnalytics() async {
    try {
      return await _api.fetchDepartmentAnalytics(
        widget.sessionController.requireToken,
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget.sessionController.handleUnauthorized();
        return const <DepartmentAnalytics>[];
      }
      rethrow;
    }
  }

  Future<void> _refreshAnalytics() async {
    final nextFuture = _loadAnalytics();
    setState(() {
      _analyticsFuture = nextFuture;
    });
    await nextFuture;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.sessionController.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HOD Dashboard'),
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
            colors: [Color(0xFFF0FDFA), Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<DepartmentAnalytics>>(
            future: _analyticsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _HodErrorState(
                  message: snapshot.error.toString(),
                  onRetry: _refreshAnalytics,
                );
              }

              final analytics = snapshot.data ?? const <DepartmentAnalytics>[];
              final totalStudents = analytics.fold<int>(
                0,
                (total, item) => total + item.totalStudents,
              );

              return RefreshIndicator(
                onRefresh: _refreshAnalytics,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF155E75)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${user?.name ?? 'HOD'}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Department-level attendance insights across the college.',
                            style: TextStyle(
                              color: Color(0xFFCCFBF1),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _HodChip(
                                icon: Icons.apartment_rounded,
                                label: '${analytics.length} departments',
                              ),
                              _HodChip(
                                icon: Icons.groups_rounded,
                                label: '$totalStudents students',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Department Analytics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (analytics.isEmpty)
                      const _HodEmptyState()
                    else
                      ...analytics.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.department,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${item.totalStudents} students',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: item.attendancePercentage / 100,
                                    minHeight: 10,
                                    borderRadius: BorderRadius.circular(999),
                                    backgroundColor: const Color(0xFFE2E8F0),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${item.attendancePercentage.toStringAsFixed(1)}% attendance',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

class _HodChip extends StatelessWidget {
  const _HodChip({required this.icon, required this.label});

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

class _HodEmptyState extends StatelessWidget {
  const _HodEmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.stacked_line_chart_rounded,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            Text(
              'No department analytics yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Department attendance metrics will appear after student and attendance data are available.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HodErrorState extends StatelessWidget {
  const _HodErrorState({required this.message, required this.onRetry});

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
                  'Could not load department analytics',
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
