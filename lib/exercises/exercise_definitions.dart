import 'exercise_def.dart';

class Exercises {
  static const list = <ExerciseDef>[
    ExerciseDef(
      id: 0,
      name: '팔 앞으로 들기',
      desc: '팔을 몸 앞쪽으로 천천히 들어 올리기',
      code: 'shoulder_flexion',
    ),
    ExerciseDef(
      id: 1,
      name: '팔 옆으로 들기',
      desc: '팔을 몸 옆으로 천천히 들어 올리기',
      code: 'shoulder_abduction',
    ),
    ExerciseDef(
      id: 2,
      name: '머리 만지기',
      desc: '손을 머리 쪽으로 가져가기',
      code: 'hand_to_head',
    ),
    ExerciseDef(
      id: 3,
      name: '허리 뒤로 손 가져가기',
      desc: '손을 허리 뒤쪽으로 가져가기',
      code: 'hand_to_back',
    ),
    ExerciseDef(
      id: 4,
      name: '앞 물건 잡기',
      desc: '앞쪽 목표를 향해 손 뻗기',
      code: 'reach_forward',
    ),
    ExerciseDef(
      id: 5,
      name: '옆 물건 잡기',
      desc: '옆쪽 목표를 향해 손 뻗기',
      code: 'reach_side',
    ),
    ExerciseDef(
      id: 6,
      name: '팔 굽히기',
      desc: '팔꿈치를 굽혀 손을 몸 쪽으로 가져오기',
      code: 'elbow_flexion',
    ),
    ExerciseDef(
      id: 7,
      name: '팔 펴기',
      desc: '굽힌 팔을 다시 펴기',
      code: 'elbow_extension',
    ),
  ];

  static ExerciseDef byId(int id) {
    return list.firstWhere(
          (e) => e.id == id,
      orElse: () => ExerciseDef(
        id: id,
        name: '운동 $id',
        desc: '',
        code: 'unknown',
      ),
    );
  }
}