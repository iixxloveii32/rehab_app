import 'exercise_def.dart';

class Exercises {
  static const list = <ExerciseDef>[
    ExerciseDef(id: 0, name: '전방 거상',       desc: '0→90° 양팔',      code: 'overhead_raise'),
    ExerciseDef(id: 1, name: '외전',           desc: '0→70° 양팔',      code: 'abduction'),
    ExerciseDef(id: 2, name: '팔꿈치 굴곡/신전', desc: '어깨 고정',        code: 'elbow_flex_ext'),
    ExerciseDef(id: 3, name: '전완 회내/회외',   desc: '팔꿈치 90°',       code: 'pron_sup'),
    ExerciseDef(id: 4, name: '손목 굴곡/신전',   desc: '전완 고정',        code: 'wrist_flex_ext'),
    ExerciseDef(id: 5, name: '그립',           desc: '펴기↔주먹',        code: 'grip_open_close'),
    ExerciseDef(id: 6, name: '엄지-검지 집기',   desc: 'pinch/opposition', code: 'pinch'),
    ExerciseDef(id: 7, name: '양손 과제',       desc: '박수/수건 당기기',  code: 'bimanual_task'),
  ];

  static ExerciseDef byId(int id) {
    return list.firstWhere(
      (e) => e.id == id,
      orElse: () => ExerciseDef(id: id, name: '운동 $id', desc: '', code: 'unknown'),
    );
  }
}