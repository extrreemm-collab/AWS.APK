import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api.dart';
import '../state/session_controller.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.sessionController,
    required this.course,
  });

  final SessionController sessionController;
  final CourseSummary course;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late DateTime _selectedDate;
  List<AttendanceSheetEntry> _entries = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _saveErrorMessage;

  AmsApi get _api => widget.sessionController.api;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _saveErrorMessage = null;
    });

    try {
      final entries = await _api.fetchAttendanceSheet(
        widget.sessionController.requireToken,
        courseId: widget.course.id,
        date: _selectedDate,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget.sessionController.handleUnauthorized();
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _entries = const [];
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _entries = const [];
        _errorMessage = 'Could not load attendance for this date.';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = pickedDate;
    });
    await _loadAttendance();
  }

  void _updateStatus(int studentId, AttendanceMark status) {
    setState(() {
      _entries = _entries
          .map(
            (entry) => entry.studentId == studentId
                ? entry.copyWith(status: status)
                : entry,
          )
          .toList();
    });
  }

  void _markAll(AttendanceMark status) {
    setState(() {
      _entries = _entries
          .map((entry) => entry.copyWith(status: status))
          .toList();
    });
  }

  Future<void> _saveAttendance() async {
    if (_entries.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
    });

    try {
      await _api.markAttendance(
        widget.sessionController.requireToken,
        MarkAttendanceRequest.fromEntries(
          courseId: widget.course.id,
          date: _selectedDate,
          entries: _entries,
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved successfully.')),
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget.sessionController.handleUnauthorized();
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _saveErrorMessage = error.message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saveErrorMessage = 'Could not save attendance right now.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save attendance right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, MMM d').format(_selectedDate);
    final presentCount = _entries
        .where((entry) => entry.status == AttendanceMark.present)
        .length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.course.courseName)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: FilledButton.icon(
          onPressed: _isSaving || _isLoading || _entries.isEmpty
              ? null
              : _saveAttendance,
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isSaving ? 'Saving...' : 'Save Attendance'),
        ),
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
          child: RefreshIndicator(
            onRefresh: _loadAttendance,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF164E63)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.course.courseName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _TopChip(
                            icon: Icons.calendar_today_outlined,
                            label: dateLabel,
                          ),
                          _TopChip(
                            icon: Icons.groups_rounded,
                            label: '${_entries.length} students',
                          ),
                          _TopChip(
                            icon: Icons.check_circle_outline_rounded,
                            label: '$presentCount present',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.edit_calendar_rounded),
                        label: const Text('Change Date'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ActionChip(
                      avatar: const Icon(
                        Icons.done_all_rounded,
                        size: 18,
                        color: Color(0xFF0F766E),
                      ),
                      backgroundColor: Colors.white,
                      label: const Text('Mark all present'),
                      onPressed: _entries.isEmpty
                          ? null
                          : () => _markAll(AttendanceMark.present),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.person_off_outlined,
                        size: 18,
                        color: Color(0xFFB45309),
                      ),
                      backgroundColor: Colors.white,
                      label: const Text('Mark all absent'),
                      onPressed: _entries.isEmpty
                          ? null
                          : () => _markAll(AttendanceMark.absent),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_saveErrorMessage != null) ...[
                  _AttendanceSaveErrorCard(message: _saveErrorMessage!),
                  const SizedBox(height: 18),
                ],
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_errorMessage != null)
                  _AttendanceErrorCard(
                    message: _errorMessage!,
                    onRetry: _loadAttendance,
                  )
                else if (_entries.isEmpty)
                  const _EmptyAttendanceState()
                else
                  ..._entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _AttendanceEntryCard(
                        entry: entry,
                        onChanged: (status) =>
                            _updateStatus(entry.studentId, status),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceEntryCard extends StatelessWidget {
  const _AttendanceEntryCard({required this.entry, required this.onChanged});

  final AttendanceSheetEntry entry;
  final ValueChanged<AttendanceMark> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.studentName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${entry.usn}  •  ${entry.department}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<AttendanceMark>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<AttendanceMark>(
                    value: AttendanceMark.present,
                    icon: Icon(Icons.check_circle_outline_rounded),
                    label: Text('Present'),
                  ),
                  ButtonSegment<AttendanceMark>(
                    value: AttendanceMark.absent,
                    icon: Icon(Icons.highlight_off_rounded),
                    label: Text('Absent'),
                  ),
                ],
                selected: {entry.status},
                onSelectionChanged: (selection) => onChanged(selection.first),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopChip extends StatelessWidget {
  const _TopChip({required this.icon, required this.label});

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

class _AttendanceErrorCard extends StatelessWidget {
  const _AttendanceErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 46,
              color: Color(0xFFB45309),
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load this attendance sheet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _AttendanceSaveErrorCard extends StatelessWidget {
  const _AttendanceSaveErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance was not saved',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAttendanceState extends StatelessWidget {
  const _EmptyAttendanceState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.person_search_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
            Text(
              'No students found',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'This course does not have enrolled students yet, so there is nothing to mark for this date.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
