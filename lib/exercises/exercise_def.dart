class ExerciseDef {
  final int id;                 // 0~7
  final String name;            // 표시 이름
  final String desc;            // 짧은 설명
  final String code;            // 서버/연구용 코드 (예: "overhead_raise")
  final int schemaVersion;      // 점수 스키마/알고리즘 버전 관리용 (선택)

  const ExerciseDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.code,
    this.schemaVersion = 1,
  });
}