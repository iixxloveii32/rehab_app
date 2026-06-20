class ExerciseDef {
  final int id;
  final String name;
  final String desc;

  /// 서버/연구용 코드
  /// 기존 서버 코드와 직접 연결하지 않더라도, CSV 분석용으로 남겨둘 수 있음
  final String code;

  /// 점수 스키마/알고리즘 버전
  final int schemaVersion;

  /// 환자에게 보여줄 과제지향 이름
  /// 예: 선반 위 물건 잡기
  final String taskTitle;

  /// 환자에게 보여줄 과제 설명
  final String taskDescription;

  /// record/review 화면에서 보여줄 안내 문구
  final String taskGuide;

  /// 과제 이미지 경로
  final String taskImagePath;

  /// 1분 동안 목표 성공 횟수
  final int taskTargetCount;

  const ExerciseDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.code,
    this.schemaVersion = 2,
    required this.taskTitle,
    required this.taskDescription,
    required this.taskGuide,
    required this.taskImagePath,
    required this.taskTargetCount,
  });
}

class Exercises {
  static const list = <ExerciseDef>[
    ExerciseDef(
      id: 0,
      name: '팔 앞으로 들기',
      desc: '팔을 앞으로 천천히 들어 올립니다.',
      code: 'forward_raise',
      taskTitle: '선반 위 물건 잡기',
      taskDescription: '선반 위 물건을 잡는 것처럼 팔을 앞으로 들어 올려보세요.',
      taskGuide: '건강한 팔로 10초 동안 2회 천천히 반복합니다.',
      taskImagePath: 'assets/images/tasks/task_00_shelf.png',
      taskTargetCount: 5,
    ),
    ExerciseDef(
      id: 1,
      name: '팔 옆으로 들기',
      desc: '팔을 옆으로 천천히 들어 올립니다.',
      code: 'side_raise',
      taskTitle: '옷 입기',
      taskDescription: '옷을 입을 때처럼 팔을 옆으로 들어보세요.',
      taskGuide: '건강한 팔로 10초 동안 2회 천천히 반복합니다.',
      taskImagePath: 'assets/images/tasks/task_01_shirt.png',
      taskTargetCount: 5,
    ),
    ExerciseDef(
      id: 2,
      name: '머리 만지기',
      desc: '손을 머리 쪽으로 가져갑니다.',
      code: 'touch_head',
      taskTitle: '머리 빗기',
      taskDescription: '머리를 빗거나 만지는 것처럼 손을 머리 쪽으로 가져가보세요.',
      taskGuide: '건강한 팔로 10초 동안 2회 천천히 반복합니다.',
      taskImagePath: 'assets/images/tasks/task_02_comb.png',
      taskTargetCount: 5,
    ),
    ExerciseDef(
      id: 3,
      name: '허리 뒤로 손 가져가기',
      desc: '손을 허리 뒤쪽으로 가져갑니다.',
      code: 'hand_behind_back',
      taskTitle: '옷 정리하기',
      taskDescription: '허리 뒤쪽의 옷을 정리하는 것처럼 손을 뒤로 가져가보세요.',
      taskGuide: '건강한 팔로 10초 동안 2회 천천히 반복합니다.',
      taskImagePath: 'assets/images/tasks/task_03_back_clothes.png',
      taskTargetCount: 5,
    ),
    ExerciseDef(
      id: 4,
      name: '앞으로 손 뻗기',
      desc: '화면의 목표 지점을 향해 손을 앞으로 뻗습니다.',
      code: 'forward_reach',
      taskTitle: '앞의 컵 잡기',
      taskDescription: '앞에 있는 컵을 잡는 것처럼 손을 앞으로 뻗어보세요.',
      taskGuide: '건강한 팔로 10초 동안 2회 천천히 반복합니다.',
      taskImagePath: 'assets/images/tasks/task_04_front_cup.png',
      taskTargetCount: 5,
    ),
    ExerciseDef(
      id: 5,
      name: '옆으로 손 뻗기',
      desc: '화면의 목표 지점을 향해 손을 옆으로 뻗습니다.',
      code: 'side_reach',
      taskTitle: '옆 물건 잡기',
      taskDescription: '옆에 있는 물건을 잡는 것처럼 손을 옆으로 뻗어보세요.',
      taskGuide: '건강한 팔로 10초 동안 2회 천천히 반복합니다.',
      taskImagePath: 'assets/images/tasks/task_05_side_cup.png',
      taskTargetCount: 5,
    ),
    ExerciseDef(
      id: 6,
      name: '팔 굽히기',
      desc: '팔꿈치를 천천히 굽힙니다.',
      code: 'elbow_flexion',
      taskTitle: '숟가락 입으로 가져오기',
      taskDescription: '숟가락을 입 쪽으로 가져오는 것처럼 팔을 굽혀보세요.',
      taskGuide: '건강한 팔로 10초 동안 2회 천천히 반복합니다.',
      taskImagePath: 'assets/images/tasks/task_06_spoon.png',
      taskTargetCount: 5,
    ),
    ExerciseDef(
      id: 7,
      name: '팔 펴기',
      desc: '팔꿈치를 천천히 폅니다.',
      code: 'elbow_extension',
      taskTitle: '앞으로 손 뻗기',
      taskDescription: '앞의 물건을 밀거나 손을 앞으로 뻗는 것처럼 팔을 펴보세요.',
      taskGuide: '건강한 팔로 10초 동안 2회 천천히 반복합니다.',
      taskImagePath: 'assets/images/tasks/task_07_push_button.png',
      taskTargetCount: 5,
    ),
  ];

  static ExerciseDef byId(int id) {
    return list.firstWhere(
          (e) => e.id == id,
      orElse: () => list.first,
    );
  }
}