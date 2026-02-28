import 'package:isar/isar.dart';

import '../models/patient.dart';
import 'isar_db.dart';

class PatientStore {
  static Future<void> save(Patient patient) async {
    final isar = IsarDB.instance;
    await isar.writeTxn(() async {
      await isar.patients.put(patient);
    });
  }
  static Future<int> saveAndReturnId(Patient patient) async {
    final isar = IsarDB.instance;
    late int id;
    await isar.writeTxn(() async {
      id = await isar.patients.put(patient);
    });
    return id;
  }
  static Future<Patient?> load() async {
    final isar = IsarDB.instance;

    // 최근 저장된 환자 1명: id 최대값을 찾아서 가져오기
    final lastId = await isar.patients.where().anyId().idProperty().max();
    if (lastId == null) return null;

    return await isar.patients.get(lastId);
  }

  static Future<void> clear() async {
    final isar = IsarDB.instance;
    await isar.writeTxn(() async {
      await isar.patients.clear();
    });
  }
}