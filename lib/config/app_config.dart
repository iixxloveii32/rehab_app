class AppConfig {
  // ==============================
  // Server
  // ==============================

  static const String serverBaseUrl = 'http://101.79.21.123:5000';

  static const String analyzeEndpoint = '$serverBaseUrl/analyze';

  // ==============================
  // App / Research Version
  // ==============================

  // 연구용 앱 버전
  static const String appVersion = '0.2.0-task-oriented';

  // 점수 계산 구조 버전
  static const int scoreSchemaVersion = 2;

  // 과제지향 표준화 버전
  static const String taskStandardVersion = 'task-standard-v1';

  // ==============================
  // Task-Oriented Training Time
  // ==============================

  // 건측 기준 동작 녹화 시간: 10초
  static const int recordDurationSec = 10;

  // 관찰 단계: 10초 영상 2회 반복
  static const int reviewRepeatCount = 2;

  // 기준 영상 1회 길이
  static const int reviewVideoDurationSec = 10;

  // 총 관찰 시간: 20초
  static const int reviewTotalDurationSec = 20;

  // 환측 모방 수행 시간: 60초
  static const int imitateDurationSec = 60;

  // ==============================
  // Task-Oriented Score Weight
  // ==============================

  // 기존 움직임 질 점수 반영 비율
  static const double overallWeight = 0.7;

  // 과제 성공 점수 반영 비율
  static const double taskScoreWeight = 0.3;
}