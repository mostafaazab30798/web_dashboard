import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/report_provider.dart';
import 'package:archive/archive.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;

class SchoolReportsScreen extends StatefulWidget {
  final String supervisorId;
  final String schoolId;
  final String schoolName;
  const SchoolReportsScreen(
      {required this.supervisorId,
      required this.schoolId,
      required this.schoolName,
      Key? key})
      : super(key: key);

  @override
  State<SchoolReportsScreen> createState() => _SchoolReportsScreenState();
}

class _SchoolReportsScreenState extends State<SchoolReportsScreen> {
  late Future<List<ReportItem>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _fetchReports();
  }

  Future<List<ReportItem>> _fetchReports() async {
    final reportsSnapshot = await FirebaseFirestore.instance
        .collection('supervisors')
        .doc(widget.supervisorId)
        .collection('schools')
        .doc(widget.schoolId)
        .collection('reports')
        .get();
    List<ReportItem> reports = [];
    for (final reportDoc in reportsSnapshot.docs) {
      final data = reportDoc.data();
      reports.add(ReportItem(
        description: data['description'] ?? '',
        status: data['status'] ?? '',
        completionNote: data['completionNote'] ?? '',
        images: (data['images'] as List?)?.cast<String>() ?? [],
        completionImages:
            (data['completionPhotos'] as List?)?.cast<String>() ?? [],
        createdAt: (data['timestamp'] as Timestamp?)?.toDate(),
        completedAt: (data['completed_at'] as Timestamp?)?.toDate(),
      ));
    }
    // Sort by creation date descending
    reports.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return reports;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReportProvider.beige,
      appBar: AppBar(
        backgroundColor: ReportProvider.navy,
        title: Text('تقارير ${widget.schoolName}',
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<ReportItem>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا توجد تقارير لهذه المدرسة'));
          }
          final reports = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, i) =>
                _ReportCard(report: reports[i], schoolName: widget.schoolName),
          );
        },
      ),
    );
  }
}

class ReportItem {
  final String description;
  final String status;
  final String completionNote;
  final List<String> images;
  final List<String> completionImages;
  final DateTime? createdAt;
  final DateTime? completedAt;
  ReportItem({
    required this.description,
    required this.status,
    required this.completionNote,
    required this.images,
    required this.completionImages,
    required this.createdAt,
    required this.completedAt,
  });
}

class _ReportCard extends StatelessWidget {
  final ReportItem report;
  final String schoolName;
  const _ReportCard({required this.report, required this.schoolName});
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
      case 'late_completed':
        statusColor = Colors.purple.shade700;
        statusLabel = 'متأخر مكتمل';
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
                if (report.createdAt != null)
                  Text('تاريخ الإنشاء: ${_formatDate(report.createdAt!)}',
                      style: const TextStyle(fontSize: 12)),
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.blue),
                  tooltip: 'تحميل الصور',
                  onPressed: () => _downloadReportImages(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(report.description, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            if (report.images.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('قبل الصيانة:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: report.images
                          .map((url) => GestureDetector(
                                onTap: () => _showImageDialog(context, url),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(url,
                                      width: 80, height: 80, fit: BoxFit.cover),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
            if (report.images.isNotEmpty &&
                report.completionImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],
            if (report.completionImages.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('بعد الصيانة:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: report.completionImages
                          .map((url) => GestureDetector(
                                onTap: () => _showImageDialog(context, url),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(url,
                                      width: 80, height: 80, fit: BoxFit.cover),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ] else if ((report.status == 'completed' ||
                report.status == 'late_completed')) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('لا توجد صور بعد الصيانة',
                    style: TextStyle(color: Colors.grey)),
              ),
            ],
            if (report.completionNote.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.note, size: 20, color: Colors.brown),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('ملاحظة الإكمال: ${report.completionNote}',
                            style: const TextStyle(
                                fontSize: 15,
                                color: Colors.brown,
                                fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ],
            if (report.completedAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 18, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('تاريخ الإكمال: ${_formatDate(report.completedAt!)}',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.green)),
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

  void _showImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }

  void _downloadReportImages(BuildContext context) async {
    final archive = Archive();
    // Before images
    for (int i = 0; i < report.images.length; i++) {
      final url = report.images[i];
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        archive.addFile(ArchiveFile(
            '${schoolName}/before/before_${i + 1}${_getExtension(url)}',
            response.bodyBytes.length,
            response.bodyBytes));
      }
    }
    // After images
    for (int i = 0; i < report.completionImages.length; i++) {
      final url = report.completionImages[i];
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        archive.addFile(ArchiveFile(
            '${schoolName}/after/after_${i + 1}${_getExtension(url)}',
            response.bodyBytes.length,
            response.bodyBytes));
      }
    }
    final zipData = ZipEncoder().encode(archive);
    final blob = html.Blob([zipData]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '${schoolName}_report_images.zip')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _getExtension(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    if (segments.isNotEmpty && segments.last.contains('.')) {
      return '.${segments.last.split('.').last}';
    }
    return '';
  }
}
