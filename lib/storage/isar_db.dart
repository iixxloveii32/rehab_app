import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/patient.dart';
import '../models/session_log.dart';

class IsarDB {
  static Isar? _isar;

  static Isar get instance {
    final isar = _isar;
    if (isar == null) {
      throw StateError('IsarDB is not initialized. Call IsarDB.init() first.');
    }
    return isar;
  }

  static Future<void> init() async {
    if (_isar != null) return;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        PatientSchema,
        SessionLogSchema,
      ],
      directory: dir.path,
      inspector: true,
    );

    debugPrint('Isar DB opened at: ${dir.path}');
  }
}