import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screening_plan.dart';

class ScreeningScreen extends StatelessWidget {
  const ScreeningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;

    final int? patientId = data?['patientId'] as int?;
    final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';

    return Scaffold(
      appBar: AppBar(
        title: const Text('상지 기능 평가'),
      ),
      body: SafeArea(
        child: Padding(
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
                      '상지 기능 평가',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '간단한 5가지 동작을 통해 현재 상지 기능을 확인합니다.\n'
                          '화면 안내에 따라 천천히 움직여 주세요.\n'
                          '각 동작은 예시와 안내 문구가 함께 제공됩니다.',
                      style: TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '평가 동작',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: screeningFunctionItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = screeningFunctionItems[index];
                    return ListTile(
                      tileColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(item.title),
                      subtitle: Text(item.desc),
                      trailing: const Icon(Icons.chevron_right),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (patientId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('먼저 사용자를 선택해 주세요.')),
                      );
                      return;
                    }

                    final screeningSessionUuid =
                        'screening_${DateTime.now().microsecondsSinceEpoch}';

                    context.go('/screening-camera', extra: {
                      'patientId': patientId,
                      'affectedSide': affectedSide,
                      'screeningIndex': 0,
                      'screeningTotal': screeningFunctionItems.length,
                      'screeningSessionUuid': screeningSessionUuid,
                      'screeningScores': <String, int>{},
                      'fromAutoFlow': true,
                    });
                  },
                  child: const Text('평가 시작하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}