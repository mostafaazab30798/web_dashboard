import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'providers/report_provider.dart';
import 'screens/overview_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReportProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverviewDashboardScreen(),
    );
  }
}
