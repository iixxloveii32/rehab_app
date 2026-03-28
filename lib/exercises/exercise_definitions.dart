class ExerciseDef {
  final int id;
  final String name;
  final String desc;

  const ExerciseDef({
    required this.id,
    required this.name,
    required this.desc,
  });
}

class Exercises {
  static const list = <ExerciseDef>[
    ExerciseDef(
      id: 0,
      name: '팔 앞으로 들기',
      desc: '팔을 앞으로 천천히 들어 올립니다.',
    ),
    ExerciseDef(
      id: 1,
      name: '팔 옆으로 들기',
      desc: '팔을 옆으로 천천히 들어 올립니다.',
    ),
    ExerciseDef(
      id: 2,
      name: '머리 만지기',
      desc: '손을 머리 쪽으로 가져갑니다.',
    ),
    ExerciseDef(
      id: 3,
      name: '허리 뒤로 손 가져가기',
      desc: '손을 허리 뒤쪽으로 가져갑니다.',
    ),
    ExerciseDef(
      id: 4,
      name: '앞으로 손 뻗기',
      desc: '화면의 목표 지점을 향해 손을 앞으로 뻗습니다.',
    ),
    ExerciseDef(
      id: 5,
      name: '옆으로 손 뻗기',
      desc: '화면의 목표 지점을 향해 손을 옆으로 뻗습니다.',
    ),
    ExerciseDef(
      id: 6,
      name: '팔 굽히기',
      desc: '팔꿈치를 천천히 굽힙니다.',
    ),
    ExerciseDef(
      id: 7,
      name: '팔 펴기',
      desc: '팔꿈치를 천천히 폅니다.',
    ),
  ];
  static ExerciseDef byId(int id) {
    return list.firstWhere(
          (e) => e.id == id,
      orElse: () => list.first,
    );
  }
}
