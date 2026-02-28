import 'package:isar/isar.dart';

part 'evaluation.g.dart';

@collection
class Evaluation {
  Id id = Isar.autoIncrement;

  late String patientName;
  late DateTime date;
  late int patientId;

  // 6개 항목(1~7점)
  int rolling = 1;
  int comeToSit = 1;
  int sitToStand = 1;
  int transfer = 1;
  int gait = 1;
  int stair = 1;

  int get totalScore =>
      rolling + comeToSit + sitToStand + transfer + gait + stair;
}