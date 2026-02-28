import 'package:flutter/material.dart';
import 'storage/isar_db.dart';
import 'screens/eval_test_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarDB.init();
  runApp(const RehabApp());
}

class RehabApp extends StatelessWidget {
  const RehabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rehab App',
      home: const EvalTestPage(),
    );
  }
}