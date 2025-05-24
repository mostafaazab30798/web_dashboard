import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/report_provider.dart';
import 'school_reports_screen.dart';

class SupervisorDetailsScreen extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  const SupervisorDetailsScreen(
      {required this.supervisorId, required this.supervisorName, Key? key})
      : super(key: key);

  @override
  State<SupervisorDetailsScreen> createState() =>
      _SupervisorDetailsScreenState();
}

class _SupervisorDetailsScreenState extends State<SupervisorDetailsScreen> {
  late Future<List<SchoolSummary>> _schoolsFuture;

  @override
  void initState() {
    super.initState();
    _schoolsFuture = _fetchSchools();
  }

  Future<List<SchoolSummary>> _fetchSchools() async {
    final schoolsSnapshot = await FirebaseFirestore.instance
        .collection('supervisors')
        .doc(widget.supervisorId)
        .collection('schools')
        .get();
    List<SchoolSummary> schools = [];
    for (final schoolDoc in schoolsSnapshot.docs) {
      final schoolName = schoolDoc.data()['name'] ?? '';
      final schoolId = schoolDoc.id;
      final reportsSnapshot =
          await schoolDoc.reference.collection('reports').get();
      int inProgress = 0, completed = 0, late = 0, lateCompleted = 0;
      for (final reportDoc in reportsSnapshot.docs) {
        final status = reportDoc['status'] ?? 'inprogress';
        if (status == 'completed')
          completed++;
        else if (status == 'late')
          late++;
        else if (status == 'late_completed')
          lateCompleted++;
        else
          inProgress++;
      }
      schools.add(SchoolSummary(
        schoolId: schoolId,
        schoolName: schoolName,
        inProgress: inProgress,
        completed: completed,
        late: late,
        lateCompleted: lateCompleted,
      ));
    }
    // Sort by school name
    schools.sort((a, b) => a.schoolName.compareTo(b.schoolName));
    return schools;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReportProvider.beige,
      appBar: AppBar(
        backgroundColor: ReportProvider.navy,
        title: Text('مدارس ${widget.supervisorName}',
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<SchoolSummary>>(
        future: _schoolsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا توجد مدارس لهذا المشرف'));
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
                  subtitle: Row(
                    children: [
                      _MiniStat(
                          label: 'قيد التنفيذ',
                          value: school.inProgress,
                          color: Colors.orange.shade700),
                      _MiniStat(
                          label: 'مكتملة',
                          value: school.completed,
                          color: Colors.green.shade700),
                      _MiniStat(
                          label: 'متأخرة',
                          value: school.late,
                          color: Colors.red.shade700),
                      if (school.lateCompleted > 0)
                        _MiniStat(
                            label: 'متأخرة مكتملة',
                            value: school.lateCompleted,
                            color: Colors.purple.shade700),
                    ],
                  ),
                  trailing:
                      const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SchoolReportsScreen(
                          supervisorId: widget.supervisorId,
                          schoolId: school.schoolId,
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

class SchoolSummary {
  final String schoolId;
  final String schoolName;
  final int inProgress;
  final int completed;
  final int late;
  final int lateCompleted;
  SchoolSummary({
    required this.schoolId,
    required this.schoolName,
    required this.inProgress,
    required this.completed,
    required this.late,
    required this.lateCompleted,
  });
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
