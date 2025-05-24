import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/report_provider.dart';

class SupervisorMaintenanceSchoolsScreen extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  const SupervisorMaintenanceSchoolsScreen(
      {required this.supervisorId, required this.supervisorName, Key? key})
      : super(key: key);

  @override
  State<SupervisorMaintenanceSchoolsScreen> createState() =>
      _SupervisorMaintenanceSchoolsScreenState();
}

class _SupervisorMaintenanceSchoolsScreenState
    extends State<SupervisorMaintenanceSchoolsScreen> {
  late Future<List<MaintenanceSchoolSummary>> _schoolsFuture;

  @override
  void initState() {
    super.initState();
    _schoolsFuture = _fetchSchools();
  }

  Future<List<MaintenanceSchoolSummary>> _fetchSchools() async {
    final maintenanceSnapshot = await FirebaseFirestore.instance
        .collection('supervisors')
        .doc(widget.supervisorId)
        .collection('regular_maintenance')
        .get();
    // Group by school_name
    final Map<String, int> schoolCounts = {};
    for (final doc in maintenanceSnapshot.docs) {
      final schoolName = doc['school_name'] ?? 'مدرسة غير معروفة';
      schoolCounts[schoolName] = (schoolCounts[schoolName] ?? 0) + 1;
    }
    final schools = schoolCounts.entries
        .map((e) => MaintenanceSchoolSummary(schoolName: e.key, count: e.value))
        .toList();
    schools.sort((a, b) => a.schoolName.compareTo(b.schoolName));
    return schools;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReportProvider.beige,
      appBar: AppBar(
        backgroundColor: ReportProvider.navy,
        title: Text('مدارس الصيانة - ${widget.supervisorName}',
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<MaintenanceSchoolSummary>>(
        future: _schoolsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا توجد مدارس صيانة لهذا المشرف'));
          }
          final schools = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: schools.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, i) {
              final school = schools[i];
              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(school.schoolName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('عدد الصيانات: ${school.count}',
                      style: const TextStyle(color: Colors.green)),
                  trailing:
                      const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SchoolMaintenanceReportsScreen(
                          supervisorId: widget.supervisorId,
                          schoolName: school.schoolName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MaintenanceSchoolSummary {
  final String schoolName;
  final int count;
  MaintenanceSchoolSummary({required this.schoolName, required this.count});
}

class SchoolMaintenanceReportsScreen extends StatefulWidget {
  final String supervisorId;
  final String schoolName;
  const SchoolMaintenanceReportsScreen(
      {required this.supervisorId, required this.schoolName, Key? key})
      : super(key: key);

  @override
  State<SchoolMaintenanceReportsScreen> createState() =>
      _SchoolMaintenanceReportsScreenState();
}

class _SchoolMaintenanceReportsScreenState
    extends State<SchoolMaintenanceReportsScreen> {
  late Future<List<MaintenanceReportItem>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _fetchReports();
  }

  Future<List<MaintenanceReportItem>> _fetchReports() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('supervisors')
        .doc(widget.supervisorId)
        .collection('regular_maintenance')
        .where('school_name', isEqualTo: widget.schoolName)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return MaintenanceReportItem(
        date: (data['date'] as Timestamp?)?.toDate(),
        status: data['status'] ?? '',
        note: data['note'] ?? '',
        timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReportProvider.beige,
      appBar: AppBar(
        backgroundColor: ReportProvider.navy,
        title: Text('صيانات ${widget.schoolName}',
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<MaintenanceReportItem>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا توجد صيانات لهذه المدرسة'));
          }
          final reports = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, i) =>
                _MaintenanceReportCard(report: reports[i]),
          );
        },
      ),
    );
  }
}

class MaintenanceReportItem {
  final DateTime? date;
  final String status;
  final String note;
  final DateTime? timestamp;
  MaintenanceReportItem(
      {required this.date,
      required this.status,
      required this.note,
      required this.timestamp});
}

class _MaintenanceReportCard extends StatelessWidget {
  final MaintenanceReportItem report;
  const _MaintenanceReportCard({required this.report});
  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    switch (report.status) {
      case 'completed':
        statusColor = Colors.green.shade700;
        statusLabel = 'مكتمل';
        break;
      case 'late':
        statusColor = Colors.red.shade700;
        statusLabel = 'متأخر';
        break;
      case 'inprogress':
      default:
        statusColor = Colors.orange.shade700;
        statusLabel = 'قيد التنفيذ';
    }
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                if (report.date != null)
                  Text('تاريخ الزيارة: ${_formatDate(report.date!)}',
                      style: const TextStyle(fontSize: 12)),
              ],
            ),
            if (report.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.note, size: 18, color: Colors.brown),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text('ملاحظة: ${report.note}',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.brown))),
                ],
              ),
            ],
            if (report.timestamp != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 4),
                  Text('تاريخ الإضافة: ${_formatDate(report.timestamp!)}',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.blueGrey)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
