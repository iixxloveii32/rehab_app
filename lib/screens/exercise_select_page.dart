import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExerciseSelectPage extends StatelessWidget {
  const ExerciseSelectPage({super.key});

  static const _items = <_ExerciseItem>[
    _ExerciseItem(0, '전방 거상', '0→90° 양팔'),
    _ExerciseItem(1, '외전', '0→70° 양팔'),
    _ExerciseItem(2, '팔꿈치 굴곡/신전', '어깨 고정'),
    _ExerciseItem(3, '전완 회내/회외', '팔꿈치 90°'),
    _ExerciseItem(4, '손목 굴곡/신전', '전완 고정'),
    _ExerciseItem(5, '그립', '펴기↔주먹'),
    _ExerciseItem(6, '엄지-검지 집기', 'pinch/opposition'),
    _ExerciseItem(7, '양손 과제', '박수/수건 당기기'),
  ];

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;
    final patientId = (data?['patientId'] as int?) ?? -1;

    return Scaffold(
      appBar: AppBar(title: const Text('동작 선택')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final it = _items[i];
          return ListTile(
            tileColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(it.name),
            subtitle: Text(it.desc),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final sessionUuid = DateTime.now().microsecondsSinceEpoch.toString();

              context.go('/record', extra: {
                'patientId': patientId,
                'exerciseId': it.id,
                'sessionUuid': sessionUuid, // ✅ 추가
              });
            },
          );
        },
      ),
    );
  }
}

class _ExerciseItem {
  final int id;
  final String name;
  final String desc;
  const _ExerciseItem(this.id, this.name, this.desc);
}