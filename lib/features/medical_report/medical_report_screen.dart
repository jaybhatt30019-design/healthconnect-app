// lib/features/medical_report/medical_report_screen.dart

import 'package:flutter/material.dart';
import 'package:healthconnect/theme/app_design_system.dart';
import 'package:healthconnect/core/services/report_service.dart';
import 'package:healthconnect/core/services/pdf_service.dart';
import 'package:healthconnect/models/medical_history_model.dart';

class MedicalReportScreen extends StatefulWidget {
  const MedicalReportScreen({super.key});

  @override
  State<MedicalReportScreen> createState() =>
      _MedicalReportScreenState();
}

class _MedicalReportScreenState
    extends State<MedicalReportScreen> {
  MedicalReport? _report;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  // Active filter — null = show all
  TimelineEventType? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final report = await ReportService().generateReport();
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _export() async {
    if (_report == null) return;
    setState(() => _isExporting = true);
    try {
      await PdfService.generateAndShare(_report!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  List<TimelineEvent> get _filteredEvents {
    final events = _report?.timelineEvents ?? [];
    if (_filter == null) return events;
    return events
        .where((e) => e.type == _filter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [

              // ── Header ────────────────────────────
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    AppBackButton(
                        onTap: () => Navigator.pop(context)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text("Medical Report",
                          style: AppTextStyles.heading),
                    ),
                    // Export button
                    if (!_isLoading && _report != null)
                      GestureDetector(
                        onTap: _isExporting ? null : _export,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: _isExporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  children: [
                                    Icon(Icons.picture_as_pdf,
                                        color: Colors.white,
                                        size: 16),
                                    SizedBox(width: 4),
                                    Text("Export PDF",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w600,
                                        )),
                                  ],
                                ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Body ──────────────────────────────
              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Loading medical data..."),
                      ],
                    ),
                  ),
                )
              else if (_error != null)
                Expanded(child: _errorState())
              else if (_report == null ||
                  _report!.timelineEvents.isEmpty)
                Expanded(child: _emptyState())
              else ...[
                // Summary chips
                _buildSummaryRow(),

                // Filter chips
                _buildFilterRow(),

                // Timeline
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      itemCount:
                          _filteredEvents.length,
                      itemBuilder: (context, index) {
                        final event =
                            _filteredEvents[index];
                        final isLast = index ==
                            _filteredEvents.length - 1;
                        return _timelineItem(
                            event, isLast);
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Summary row ───────────────────────────────────
  Widget _buildSummaryRow() {
    final r = _report!;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _summaryChip(
              Icons.medication_outlined,
              '${r.medicines.length} Medicines',
              AppColors.primary,
            ),
            const SizedBox(width: 8),
            _summaryChip(
              Icons.calendar_today_outlined,
              '${r.appointments.length} Appointments',
              Colors.blue,
            ),
            const SizedBox(width: 8),
            _summaryChip(
              Icons.sick_outlined,
              '${r.history?.illnesses.length ?? 0} Illnesses',
              Colors.orange,
            ),
            const SizedBox(width: 8),
            _summaryChip(
              Icons.medical_services_outlined,
              '${r.history?.surgeries.length ?? 0} Surgeries',
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(
      IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Filter row ────────────────────────────────────
  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(null, "All"),
            const SizedBox(width: 8),
            _filterChip(
                TimelineEventType.medicine, "Medicines"),
            const SizedBox(width: 8),
            _filterChip(TimelineEventType.appointment,
                "Appointments"),
            const SizedBox(width: 8),
            _filterChip(
                TimelineEventType.illness, "Illnesses"),
            const SizedBox(width: 8),
            _filterChip(
                TimelineEventType.surgery, "Surgeries"),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
      TimelineEventType? type, String label) {
    final selected = _filter == type;
    return GestureDetector(
      onTap: () => setState(() => _filter = type),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected
                ? Colors.white
                : AppColors.darkPrimary,
            fontWeight: selected
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── Timeline item ─────────────────────────────────
  Widget _timelineItem(
      TimelineEvent event, bool isLast) {
    final color = _eventColor(event.type);
    final icon = _eventIcon(event.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── Left: date dot + vertical line ─────────
          SizedBox(
            width: 60,
            child: Column(
              children: [
                Text(
                  _shortDate(event.date),
                  style: AppTextStyles.small.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Right: event card ───────────────────────
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius:
                      BorderRadius.circular(AppRadius.md),
                  boxShadow: [AppShadows.light],
                  border: Border.all(
                    color:
                        color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon,
                              color: color, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            event.title,
                            style: AppTextStyles.body
                                .copyWith(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),
                        if (event.badge != null)
                          _badge(event.badge!, event.type),
                      ],
                    ),

                    if (event.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(event.subtitle,
                          style: AppTextStyles.small),
                    ],

                    if (event.detail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(event.detail,
                          style: AppTextStyles.small
                              .copyWith(fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(
      String label, TimelineEventType type) {
    Color color;
    if (label == 'Out') {
      color = Colors.red;
    } else if (label == 'Low') {
      color = Colors.amber.shade700;
    } else if (label == 'severe') {
      color = Colors.red;
    } else if (label == 'moderate') {
      color = Colors.amber.shade700;
    } else {
      color = Colors.green;
    }

    final display =
        label[0].toUpperCase() + label.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        display,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _eventColor(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.appointment:
        return Colors.blue;
      case TimelineEventType.illness:
        return Colors.orange;
      case TimelineEventType.surgery:
        return Colors.purple;
      case TimelineEventType.medicine:
        return AppColors.primary;
    }
  }

  IconData _eventIcon(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.appointment:
        return Icons.local_hospital_outlined;
      case TimelineEventType.illness:
        return Icons.sick_outlined;
      case TimelineEventType.surgery:
        return Icons.medical_services_outlined;
      case TimelineEventType.medicine:
        return Icons.medication_outlined;
    }
  }

  String _shortDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (dt.year == 2000 && dt.month == 1 && dt.day == 1) {
      return '—';
    }
    return '${months[dt.month - 1]}\n${dt.year}';
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text("Failed to load report",
                style: AppTextStyles.body),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: const Text("Retry",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                  color: AppColors.iconBg,
                  shape: BoxShape.circle),
              child: const Icon(
                  Icons.timeline_outlined,
                  size: 44,
                  color: AppColors.accent),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text("No data yet",
                style: AppTextStyles.body),
            const SizedBox(height: 8),
            Text(
              "Add medicines, appointments and\nmedical history to see your timeline",
              style: AppTextStyles.small,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}