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
  static const String appVersion = '0.3.0-rep-mean-score';

  // 점수 계산 구조 버전
  static const int scoreSchemaVersion = 3;

  // 과제지향 표준화 버전
  static const String taskStandardVersion = 'task-standard-v1';

  // ==============================
  // Automation Time
  // ==============================

  // 오늘의 상지 재활 화면에서 현재 상태 평가로 자동 이동하는 시간
  static const int exercisePageAutoStartSec = 10;

  // 현재 상태 평가 안내 화면에서 실제 평가 화면으로 자동 이동하는 시간
  static const int screeningIntroAutoStartSec = 10;

  // 평가 결과 화면에서 추천운동 시작 전 확인 시간
  static const int screeningResultAutoStartSec = 10;

  // 피드백 화면에서 다음 운동 또는 결과 화면으로 자동 이동하는 시간
  static const int feedbackAutoNextSec = 5;

  // 평가/촬영/따라하기 실제 시작 직전 카운트다운 시간
  static const int startCountdownSec = 3;

  // 서버 분석 대기 timeout
  static const int analyzeTimeoutSec = 180;

  // ==============================
  // Task-Oriented Training Time
  // ==============================

  // 건측 기준 동작 녹화 시간
  static const int recordDurationSec = 10;

  // 관찰 단계: 기준 영상 반복 횟수
  static const int reviewRepeatCount = 2;

  // 기준 영상 1회 길이
  static const int reviewVideoDurationSec = 10;

  // 총 관찰 시간
  static const int reviewTotalDurationSec = 20;

  // 환측 모방 수행 시간
  static const int imitateDurationSec = 60;

  // 스크리닝 평가 동작 녹화 시간
  static const int screeningRecordDurationSec = 5;

  // ==============================
  // Camera Guide
  // ==============================

  // 카메라 화면 내 어깨 기준선 위치 비율
  static const double shoulderGuideYRatio = 0.42;

  // 좌우 안전선 위치 비율
  static const double sideSafeMarginRatio = 0.09;

  // 하단 안전선 위치 비율
  static const double bottomSafeLineRatio = 0.88;

  // ==============================
  // Task-Oriented Score Weight
  // ==============================

  // 기존 움직임 질 점수 반영 비율
  static const double overallWeight = 0.7;

  // 과제 성공 점수 반영 비율
  static const double taskScoreWeight = 0.3;
}
