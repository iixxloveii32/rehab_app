import 'package:flutter/material.dart';
import 'app_router.dart';
import 'storage/isar_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarDB.init();
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