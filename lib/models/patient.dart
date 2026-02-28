import 'package:isar/isar.dart';

part 'patient.g.dart';

@collection
class Patient {
  Id id = Isar.autoIncrement;

  late String name; // 환자명
  late String sex; // 'M' or 'F'
  late DateTime birthDate;

  // ✅ 기존 코드 호환용 named constructor
  Patient({
    required this.name,
    required this.sex,
    required this.birthDate,
  });
}