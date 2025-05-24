import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/report_provider.dart';
import 'supervisor_details_screen.dart';
import 'supervisor_maintenance_schools_screen.dart';
import '../dashboard.dart';

class OverviewDashboardScreen extends StatelessWidget {
  const OverviewDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportProvider>(context);
    // Fetch stats on first build if not already loaded
    if (provider.supervisorStats.isEmpty) {
      provider.fetchDashboardStats();
    }
    return Scaffold(
      backgroundColor: ReportProvider.beige,
      appBar: AppBar(
        backgroundColor: ReportProvider.navy,
        title:
            const Text('لوحة البيانات', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => provider.fetchDashboardStats(),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => provider.fetchDashboardStats(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  label: 'إجمالي البلاغات',
                  value: provider.totalReports,
                  icon: Icons.report,
                  color: ReportProvider.navy,
                ),
                _StatCard(
                  label: 'إجمالي الصيانات الدورية',
                  value: provider.totalRegularMaintenance,
                  icon: Icons.build,
                  color: ReportProvider.navy,
                ),
                _StatCard(
                  label: 'بلاغات قيد التنفيذ',
                  value: provider.totalInProgressReports,
                  icon: Icons.timelapse,
                  color: Colors.orange.shade700,
                ),
                _StatCard(
                  label: 'بلاغات مكتملة',
                  value: provider.totalCompletedReports,
                  icon: Icons.check_circle,
                  color: Colors.green.shade700,
                ),
                _StatCard(
                  label: 'بلاغات متأخرة',
                  value: provider.totalLateReports,
                  icon: Icons.error,
                  color: Colors.red.shade700,
                ),
                _StatCard(
                  label: 'بلاغات متأخرة مكتملة',
                  value: provider.totalLateCompletedReports,
                  icon: Icons.done_all,
                  color: Colors.purple.shade700,
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('إحصائيات المشرفين:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...provider.supervisorStats
                .map((s) => _SupervisorCard(stats: s))
                .toList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ReportProvider.navy,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة', style: TextStyle(color: Colors.white)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReportDashboard(initialTab: 0),
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                Text('$value',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SupervisorCard extends StatelessWidget {
  final SupervisorStats stats;
  const _SupervisorCard({required this.stats});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.school, color: Colors.blue),
                  title: const Text('مدارس البلاغات',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SupervisorDetailsScreen(
                          supervisorId: stats.supervisorId,
                          supervisorName: stats.supervisorName,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.build, color: Colors.green),
                  title: const Text('مدارس الصيانة الدورية',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SupervisorMaintenanceSchoolsScreen(
                          supervisorId: stats.supervisorId,
                          supervisorName: stats.supervisorName,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Card(
        color: Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person, color: ReportProvider.navy),
                  const SizedBox(width: 8),
                  Text(stats.supervisorName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: ReportProvider.navy)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniStat(
                      label: 'البلاغات',
                      value: stats.totalReports,
                      color: ReportProvider.navy),
                  _MiniStat(
                      label: 'قيد التنفيذ',
                      value: stats.inProgressReports,
                      color: Colors.orange.shade700),
                  _MiniStat(
                      label: 'مكتملة',
                      value: stats.completedReports,
                      color: Colors.green.shade700),
                  _MiniStat(
                      label: 'متأخرة',
                      value: stats.lateReports,
                      color: Colors.red.shade700),
                  _MiniStat(
                      label: 'متأخرة مكتملة',
                      value: stats.lateCompletedReports,
                      color: Colors.purple.shade700),
                  _MiniStat(
                      label: 'الصيانات',
                      value: stats.totalRegularMaintenance,
                      color: Colors.brown.shade700),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('معدل الإنجاز:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: stats.completionRate,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${(stats.completionRate * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
