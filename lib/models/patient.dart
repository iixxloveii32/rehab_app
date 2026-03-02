import 'package:isar/isar.dart';

part 'patient.g.dart';

@collection
class Patient {
  Id id = Isar.autoIncrement;

  late String name;      // 환자명
  late String sex;       // 'M' or 'F'
  late DateTime birthDate;

  // ⭐ 추가: 환측
  late String affectedSide;   // 'L' or 'R'

  // 생성자
  Patient({
    required this.name,
    required this.sex,
    required this.birthDate,
    this.affectedSide = 'L', // 기본값
  });
}