import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/patient.dart';

class PatientStore {
  static const _key = 'patient_profile_v1';

  static Future<void> save(Patient patient) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(patient.toJson()));
  }

  static Future<Patient?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    return Patient.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
