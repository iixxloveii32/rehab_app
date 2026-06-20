class ExerciseDef {
  final int id; // 0~7

  /// 기존 운동명
  /// 예: 팔 앞으로 들기
  final String name;

  /// 기존 짧은 설명
  final String desc;

  /// 서버/연구용 코드
  /// 예: "overhead_raise"
  final String code;

  /// 점수 스키마/알고리즘 버전 관리용
  final int schemaVersion;

  /// 환자에게 보여줄 과제지향 이름
  /// 예: 선반 위 물건 잡기
  final String taskTitle;

  /// 환자에게 보여줄 과제 설명
  /// 예: 선반 위 물건을 잡는 것처럼 팔을 앞으로 들어 올려보세요.
  final String taskDescription;

  /// 수행 안내 문구
  /// 예: 10초 동안 2회 천천히 반복합니다.
  final String taskGuide;

  /// 과제 이미지 경로
  /// 예: assets/images/tasks/task_00_shelf.png
  final String taskImagePath;

  /// 1분 동안 목표 성공 횟수
  final int taskTargetCount;

  const ExerciseDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.code,
    this.schemaVersion = 1,
    required this.taskTitle,
    required this.taskDescription,
    required this.taskGuide,
    required this.taskImagePath,
    required this.taskTargetCount,
  });
}