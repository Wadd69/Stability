import '../dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';

class StabilityApp extends StatelessWidget {
  const StabilityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stability',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
