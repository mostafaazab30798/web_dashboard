import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SupervisorStats {
  final String supervisorId;
  final String supervisorName;
  final int totalReports;
  final int inProgressReports;
  final int completedReports;
  final int lateReports;
  final int lateCompletedReports;
  final int totalRegularMaintenance;
  final double completionRate;
  final DateTime? lastActivity;

  SupervisorStats({
    required this.supervisorId,
    required this.supervisorName,
    required this.totalReports,
    required this.inProgressReports,
    required this.completedReports,
    required this.lateReports,
    required this.lateCompletedReports,
    required this.totalRegularMaintenance,
    required this.completionRate,
    required this.lastActivity,
  });
}

class ReportProvider extends ChangeNotifier {
  // State
  List<Map<String, dynamic>> supervisors = [];
  List<html.File> selectedImages = [];
  final List<String> uploadedImageUrls = [];

  // Dashboard stats
  int totalReports = 0;
  int totalRegularMaintenance = 0;
  int totalInProgressReports = 0;
  int totalCompletedReports = 0;
  int totalLateReports = 0;
  int totalLateCompletedReports = 0;
  List<SupervisorStats> supervisorStats = [];

  // Color constants
  static const Color navy = Color(0xFF1A237E);
  static const Color beige = Color(0xFFF5F5DC);

  // Fetch supervisors
  Future<void> fetchSupervisors() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('supervisors').get();
    supervisors = snapshot.docs
        .map((doc) => {'id': doc.id, 'name': doc['username']})
        .toList();
    notifyListeners();
  }

  // Image picking
  void pickImages() {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.multiple = true;
    uploadInput.click();
    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        selectedImages = List<html.File>.from(files);
        notifyListeners();
      }
    });
  }

  // Upload image to Cloudinary
  Future<String?> uploadImageToCloudinary(html.File imageFile) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(imageFile);
    await reader.onLoad.first;
    final bytes = reader.result as Uint8List;
    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/dg7rsus0g/image/upload');
    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = 'managment_upload';
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: imageFile.name,
    ));
    final response = await request.send();
    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final data = json.decode(responseData);
      return data['secure_url'];
    } else {
      return null;
    }
  }

  // Utility: extract Arabic name
  String extractArabicName(String input) {
    return RegExp(r'[\u0600-\u06FF\s]+')
        .allMatches(input.trim())
        .map((m) => m.group(0))
        .join()
        .trim();
  }

  // Submit regular report
  Future<String?> submitReport({
    required String schoolNameInput,
    required String description,
    required String? selectedType,
    required String? selectedPriority,
    required String? selectedDate,
    required String? selectedSupervisor,
    required List<html.File> images,
    required List<Map<String, dynamic>> supervisorsList,
  }) async {
    if (schoolNameInput.isEmpty ||
        description.isEmpty ||
        selectedType == null ||
        selectedPriority == null ||
        selectedDate == null ||
        selectedSupervisor == null ||
        images.isEmpty) {
      return 'يرجى تعبئة جميع الحقول';
    }
    try {
      uploadedImageUrls.clear();
      for (var image in images) {
        final url = await uploadImageToCloudinary(image);
        if (url != null) {
          uploadedImageUrls.add(url);
        } else {
          throw Exception("فشل رفع الصورة");
        }
      }
      final schoolName = extractArabicName(schoolNameInput);
      final supervisor = supervisorsList.firstWhere(
          (s) => s['name'] == selectedSupervisor,
          orElse: () => throw Exception('المشرف غير موجود'));
      final supervisorId = supervisor['id'];
      final supervisorDoc = FirebaseFirestore.instance
          .collection('supervisors')
          .doc(supervisorId);
      final schoolsCollection = supervisorDoc.collection('schools');
      final querySnapshot = await schoolsCollection
          .where('name', isEqualTo: schoolName)
          .limit(1)
          .get();
      String schoolDocId;
      if (querySnapshot.docs.isNotEmpty) {
        schoolDocId = querySnapshot.docs.first.id;
      } else {
        final newSchoolDoc = await schoolsCollection.add({'name': schoolName});
        schoolDocId = newSchoolDoc.id;
      }
      final selectedDateTime = _getDateFromSelection(selectedDate);
      await schoolsCollection.doc(schoolDocId).collection('reports').add({
        'description': description,
        'type': selectedType,
        'priority': selectedPriority,
        'images': uploadedImageUrls,
        'date': Timestamp.fromDate(selectedDateTime),
        'timestamp': Timestamp.now(),
        'status': 'inprogress',
      });
      selectedImages.clear();
      uploadedImageUrls.clear();
      notifyListeners();
      return null;
    } catch (e) {
      return 'حدث خطأ أثناء رفع البلاغ: $e';
    }
  }

  // Submit maintenance report
  Future<String?> submitMaintenanceReport({
    required String schoolNameInput,
    required String? selectedDate,
    required String? selectedSupervisor,
    required List<Map<String, dynamic>> supervisorsList,
  }) async {
    if (schoolNameInput.isEmpty ||
        selectedDate == null ||
        selectedSupervisor == null) {
      return 'يرجى تعبئة جميع الحقول';
    }
    try {
      final schoolName = extractArabicName(schoolNameInput);
      final supervisor = supervisorsList.firstWhere(
          (s) => s['name'] == selectedSupervisor,
          orElse: () => throw Exception('المشرف غير موجود'));
      final supervisorId = supervisor['id'];
      final selectedDateTime = _getDateFromSelection(selectedDate);
      await FirebaseFirestore.instance
          .collection('supervisors')
          .doc(supervisorId)
          .collection('regular_maintenance')
          .add({
        'school_name': schoolName,
        'date': Timestamp.fromDate(selectedDateTime),
        'timestamp': Timestamp.now(),
        'status': 'inprogress',
      });
      notifyListeners();
      return null;
    } catch (e) {
      return 'حدث خطأ أثناء رفع الصيانة الدورية: $e';
    }
  }

  // Utility: get date from selection
  DateTime _getDateFromSelection(String dateValue) {
    final now = DateTime.now();
    switch (dateValue) {
      case 'today':
        return now;
      case 'tomorrow':
        return now.add(const Duration(days: 1));
      case 'day_after_tomorrow':
        return now.add(const Duration(days: 2));
      default:
        return now;
    }
  }

  Future<void> fetchDashboardStats() async {
    // Reset
    totalReports = 0;
    totalRegularMaintenance = 0;
    totalInProgressReports = 0;
    totalCompletedReports = 0;
    totalLateReports = 0;
    totalLateCompletedReports = 0;
    supervisorStats = [];

    final supervisorsSnapshot =
        await FirebaseFirestore.instance.collection('supervisors').get();
    for (final doc in supervisorsSnapshot.docs) {
      final supervisorId = doc.id;
      final supervisorName = doc['username'];
      // Reports
      final schoolsSnapshot = await doc.reference.collection('schools').get();
      int supervisorTotalReports = 0;
      int supervisorInProgress = 0;
      int supervisorCompleted = 0;
      int supervisorLate = 0;
      int supervisorLateCompleted = 0;
      DateTime? lastActivity;
      for (final schoolDoc in schoolsSnapshot.docs) {
        final reportsSnapshot =
            await schoolDoc.reference.collection('reports').get();
        for (final report in reportsSnapshot.docs) {
          supervisorTotalReports++;
          totalReports++;
          final status = report['status'] ?? 'inprogress';
          final Timestamp? dateTs = report['date'] ?? report['timestamp'];
          final DateTime reportDate = dateTs?.toDate() ?? DateTime.now();
          if (status == 'inprogress') {
            supervisorInProgress++;
            totalInProgressReports++;
          } else if (status == 'completed') {
            supervisorCompleted++;
            totalCompletedReports++;
          } else if (status == 'late') {
            supervisorLate++;
            totalLateReports++;
          } else if (status == 'late_completed') {
            supervisorLateCompleted++;
            totalLateCompletedReports++;
          }
          if (lastActivity == null || reportDate.isAfter(lastActivity)) {
            lastActivity = reportDate;
          }
        }
      }
      // Regular maintenance
      final maintenanceSnapshot =
          await doc.reference.collection('regular_maintenance').get();
      int supervisorRegularMaintenance = maintenanceSnapshot.size;
      totalRegularMaintenance += supervisorRegularMaintenance;
      double completionRate = supervisorTotalReports == 0
          ? 0
          : supervisorCompleted / supervisorTotalReports;
      supervisorStats.add(SupervisorStats(
        supervisorId: supervisorId,
        supervisorName: supervisorName,
        totalReports: supervisorTotalReports,
        inProgressReports: supervisorInProgress,
        completedReports: supervisorCompleted,
        lateReports: supervisorLate,
        lateCompletedReports: supervisorLateCompleted,
        totalRegularMaintenance: supervisorRegularMaintenance,
        completionRate: completionRate,
        lastActivity: lastActivity,
      ));
    }
    notifyListeners();
  }
}
