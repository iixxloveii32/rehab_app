import 'package:isar/isar.dart';

part 'session_log.g.dart';

@collection
class SessionLog {
  Id id = Isar.autoIncrement;

  // =========================
  // Basic identifiers
  // =========================

  @Index()
  late int patientId;

  @Index()
  late int exerciseId; // 0~7

  @Index()
  late DateTime timestampKst;

  @Index()
  late String dateKey; // YYYY-MM-DD (KST)

  // =========================
  // Movement quality scores
  // =========================

  late int overall; // 0~100

  int symmetry = 0; // 좌우 균형
  int timing = 0; // 속도 맞추기
  int smoothness = 0; // 움직임 부드러움
  int compensation = 0; // 몸통 안정성
  int rom = 0; // 동작 범위

  // =========================
  // Research / app metadata
  // =========================

  @Index()
  late String sessionUuid;

  // AppConfig와 맞춘 기본값입니다.
  // 저장 시 AppConfig.appVersion / scoreSchemaVersion으로 덮어쓰는 구조를 권장합니다.
  String appVersion = '0.2.0-task-oriented';
  int scoreSchemaVersion = 2;

  // =========================
  // Reference / imitation structure
  // =========================

  @Index()
  bool isReference = false; // true: 건측 기준 영상 / false: 환측 수행 또는 평가 영상

  int attemptIndex = 0; // 같은 날짜·같은 운동 내 시도 순서 또는 스크리닝 순서

  // =========================
  // Server analysis payloads
  // =========================

  String? featuresJson;
  String? qualityJson;

  // =========================
  // Video paths
  // =========================

  String? referenceVideoPath;
  String? imitationVideoPath;
}
