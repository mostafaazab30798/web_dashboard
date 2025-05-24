import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'providers/report_provider.dart';

class ReportDashboard extends StatefulWidget {
  final int initialTab;
  const ReportDashboard({super.key, this.initialTab = 0});

  @override
  State<ReportDashboard> createState() => _ReportDashboardState();
}

class _ReportDashboardState extends State<ReportDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Regular report form controllers
  final _schoolNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedType;
  String? _selectedPriority;
  String? _selectedDate;
  String? _selectedSupervisor;

  // Maintenance report form controllers
  final _maintenanceSchoolNameController = TextEditingController();
  String? _selectedMaintenanceDate;
  String? _selectedMaintenanceSupervisor;

  final List<String> _reportTypes = [
    'كهرباء',
    'سباكة',
    'تكييف',
    'مدني',
    "مكافحة الحريق"
  ];
  final List<String> _priorities = ['طارئ', 'روتيني'];

  // Date options
  final List<Map<String, dynamic>> _dateOptions = [
    {'label': 'اليوم', 'value': 'today'},
    {'label': 'غداً', 'value': 'tomorrow'},
    {'label': 'بعد غد', 'value': 'day_after_tomorrow'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportProvider>(context, listen: false).fetchSupervisors();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _schoolNameController.dispose();
    _descriptionController.dispose();
    _maintenanceSchoolNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportProvider>(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة تحكم البلاغات'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'البلاغات العادية'),
              Tab(text: 'صيانات دورية'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRegularReportForm(provider),
            _buildMaintenanceReportForm(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildRegularReportForm(ReportProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اسم المشرف'),
            DropdownButton<String>(
              value: _selectedSupervisor,
              isExpanded: true,
              hint: const Text('اختر اسم المشرف'),
              items: provider.supervisors
                  .map((s) => DropdownMenuItem<String>(
                        value: s['name'],
                        child: Text(s['name']),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedSupervisor = value),
            ),
            const SizedBox(height: 16),
            const Text('اسم المدرسة'),
            TextField(
              controller: _schoolNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'أدخل اسم المدرسة',
              ),
            ),
            const SizedBox(height: 16),
            const Text('وصف البلاغ'),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('نوع البلاغ'),
            DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              hint: const Text('اختر نوع البلاغ'),
              items: _reportTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedType = value),
            ),
            const SizedBox(height: 16),
            const Text('أولوية البلاغ'),
            DropdownButton<String>(
              value: _selectedPriority,
              isExpanded: true,
              hint: const Text('اختر أولوية البلاغ'),
              items: _priorities
                  .map((priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(priority),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedPriority = value),
            ),
            const SizedBox(height: 16),
            const Text('تاريخ البلاغ'),
            DropdownButton<String>(
              value: _selectedDate,
              isExpanded: true,
              hint: const Text('اختر تاريخ البلاغ'),
              items: _dateOptions
                  .map((dateOption) => DropdownMenuItem<String>(
                        value: dateOption['value'] as String,
                        child: Text(dateOption['label'] as String),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedDate = value),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.pickImages(),
              child: const Text('اختيار الصور'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: provider.selectedImages
                  .map((file) => Chip(label: Text(file.name)))
                  .toList(),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final error = await provider.submitReport(
                    schoolNameInput: _schoolNameController.text,
                    description: _descriptionController.text,
                    selectedType: _selectedType,
                    selectedPriority: _selectedPriority,
                    selectedDate: _selectedDate,
                    selectedSupervisor: _selectedSupervisor,
                    images: provider.selectedImages,
                    supervisorsList: provider.supervisors,
                  );
                  if (error == null) {
                    setState(() {
                      _schoolNameController.clear();
                      _descriptionController.clear();
                      _selectedType = null;
                      _selectedPriority = null;
                      _selectedDate = null;
                      _selectedSupervisor = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم رفع البلاغ بنجاح')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error)),
                    );
                  }
                },
                child: const Text('رفع البلاغ'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceReportForm(ReportProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('اسم المدرسة'),
          TextField(
            controller: _maintenanceSchoolNameController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'أدخل اسم المدرسة',
            ),
          ),
          const SizedBox(height: 16),
          const Text('اسم المشرف'),
          DropdownButton<String>(
            value: _selectedMaintenanceSupervisor,
            isExpanded: true,
            hint: const Text('اختر اسم المشرف'),
            items: provider.supervisors
                .map((s) => DropdownMenuItem<String>(
                      value: s['name'],
                      child: Text(s['name']),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedMaintenanceSupervisor = value;
              });
            },
          ),
          const SizedBox(height: 16),
          const Text('تاريخ الزيارة'),
          DropdownButton<String>(
            value: _selectedMaintenanceDate,
            isExpanded: true,
            hint: const Text('اختر تاريخ الزيارة'),
            items: _dateOptions
                .map((dateOption) => DropdownMenuItem<String>(
                      value: dateOption['value'] as String,
                      child: Text(dateOption['label'] as String),
                    ))
                .toList(),
            onChanged: (value) =>
                setState(() => _selectedMaintenanceDate = value),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: () async {
                final error = await provider.submitMaintenanceReport(
                  schoolNameInput: _maintenanceSchoolNameController.text,
                  selectedDate: _selectedMaintenanceDate,
                  selectedSupervisor: _selectedMaintenanceSupervisor,
                  supervisorsList: provider.supervisors,
                );
                if (error == null) {
                  setState(() {
                    _maintenanceSchoolNameController.clear();
                    _selectedMaintenanceDate = null;
                    _selectedMaintenanceSupervisor = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('تم رفع الصيانة الدورية بنجاح')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                }
              },
              child: const Text('رفع الصيانة الدورية'),
            ),
          )
        ],
      ),
    );
  }
}
