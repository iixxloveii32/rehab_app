import 'package:flutter/material.dart';
import 'app_router.dart';

void main() {
  runApp(const RehabApp());
}

class RehabApp extends StatelessWidget {
  const RehabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Rehab App',
      routerConfig: appRouter,
    );
  }
}
