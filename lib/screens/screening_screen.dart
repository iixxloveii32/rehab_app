import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScreeningScreen extends StatefulWidget {
  const ScreeningScreen({super.key});

  @override
  State<ScreeningScreen> createState() => _ScreeningScreenState();
}

class _ScreeningScreenState extends State<ScreeningScreen> {
  final List<_ScreeningItem> _items = const [
    _ScreeningItem(
      exerciseId: 0,
      title: '팔 앞으로 들기',
      desc: '가능한 만큼 팔을 앞으로 천천히 들어보세요.',
      functionKey: 'flexion',
    ),
    _ScreeningItem(
      exerciseId: 1,
      title: '팔 옆으로 들기',
      desc: '가능한 만큼 팔을 옆으로 천천히 들어보세요.',
      functionKey: 'abduction',
    ),
    _ScreeningItem(
      exerciseId: 2,
      title: '머리 만지기',
      desc: '손을 머리 쪽으로 천천히 가져가 보세요.',
      functionKey: 'hand_to_head',
    ),
    _ScreeningItem(
      exerciseId: 3,
      title: '허리 뒤로 손 가져가기',
      desc: '손을 허리 뒤쪽으로 천천히 가져가 보세요.',
      functionKey: 'hand_to_back',
    ),
    _ScreeningItem(
      exerciseId: 4,
      title: '앞으로 손 뻗기',
      desc: '화면의 목표 지점을 향해 손을 앞으로 뻗어보세요.',
      functionKey: 'reach_forward',
    ),
    _ScreeningItem(
      exerciseId: 5,
      title: '옆으로 손 뻗기',
      desc: '화면의 목표 지점을 향해 손을 옆으로 뻗어보세요.',
      functionKey: 'reach_side',
    ),
    _ScreeningItem(
      exerciseId: 6,
      title: '팔 굽히기',
      desc: '팔꿈치를 천천히 굽혀보세요.',
      functionKey: 'elbow_flexion',
    ),
    _ScreeningItem(
      exerciseId: 7,
      title: '팔 펴기',
      desc: '팔꿈치를 천천히 펴보세요.',
      functionKey: 'elbow_extension',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;

    final int? patientId = data?['patientId'] as int?;
    final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';

    return Scaffold(
      appBar: AppBar(
        title: const Text('현재 상태 평가하기'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '현재 상태 평가',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '각 동작을 하나씩 촬영하여 현재 상지 기능을 평가합니다.',
                    style: TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '평가 동작 목록',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    tileColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(item.title),
                    subtitle: Text(item.desc),
                    leading: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text('${index + 1}'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final screeningSessionUuid =
                          'screening_${DateTime.now().microsecondsSinceEpoch}';

                      context.push('/screening-camera', extra: {
                        'patientId': patientId,
                        'affectedSide': affectedSide,
                        'exerciseId': item.exerciseId,
                        'functionKey': item.functionKey,
                        'title': item.title,
                        'desc': item.desc,
                        'screeningIndex': index,
                        'screeningTotal': _items.length,
                        'screeningSessionUuid': screeningSessionUuid,
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreeningItem {
  final int exerciseId;
  final String title;
  final String desc;
  final String functionKey;

  const _ScreeningItem({
    required this.exerciseId,
    required this.title,
    required this.desc,
    required this.functionKey,
  });
}