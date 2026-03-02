import 'package:isar/isar.dart';

part 'session_log.g.dart';

@collection
class SessionLog {
  Id id = Isar.autoIncrement;

  @Index()
  late int patientId;

  @Index()
  late int exerciseId; // 0~7

  @Index()
  late DateTime timestampKst;

  @Index()
  late String dateKey; // "YYYY-MM-DD" (KST)

  late int overall; // 0~100

  // sub scores (0~100)
  int symmetry = 0;
  int timing = 0;
  int smoothness = 0;
  int compensation = 0;
  int rom = 0;

  // 연구용 메타(권장)
  @Index()
  late String sessionUuid;
  String appVersion = '0.1.0';
  int scoreSchemaVersion = 1;
  // =========================
  // B(건측 ref / 환측 imit) 구조용 필드
  // =========================

  @Index()
  bool isReference = false;   // true: 건측 캘리브레이션 / false: 환측 평가

  int attemptIndex = 0;       // 같은 동작 반복 횟수

  // 분석 결과(서버/MockAnalyzer)
  String? featuresJson;
  String? qualityJson;

  // 영상 경로(재분석/디버깅 대비)
  String? referenceVideoPath;
  String? imitationVideoPath;
}