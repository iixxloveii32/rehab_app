import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../exercises/exercise_definitions.dart';
import 'screening_plan.dart';

class ScreeningResultPage extends StatelessWidget {
  const ScreeningResultPage({super.key});

  String _labelForKey(String key) {
    switch (key) {
      case 'flexion':
        return '팔 앞으로 들기';
      case 'abduction':
        return '팔 옆으로 들기';
      case 'hand_to_head':
        return '머리 만지기';
      case 'hand_to_back':
        return '허리 뒤로 손 가져가기';
      case 'reach_forward':
        return '앞으로 손 뻗기';
      default:
        return key;
    }
  }

  String _scoreComment(int score) {
    if (score >= 80) return '좋음';
    if (score >= 60) return '보통';
    return '연습 필요';
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;

    final int? patientId = data?['patientId'] as int?;
    final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';

    final Map<String, int> scores =
        (data?['screeningScores'] as Map?)
            ?.map((k, v) => MapEntry('$k', v as int)) ??
            <String, int>{};

    final recommendedIds = recommendedExerciseIdsFromScores(scores);
    final summary = screeningSummaryText(scores);

    final sortedScores = scores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('상지 기능 평가 결과'),
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
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '평가가 완료되었습니다',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                '동작별 결과',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: sortedScores.isEmpty
                    ? const Center(
                  child: Text('평가 결과가 없습니다.'),
                )
                    : ListView.separated(
                  itemCount: sortedScores.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = sortedScores[index];
                    return ListTile(
                      tileColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(_labelForKey(item.key)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_scoreComment(item.value)),
                      ),
                      trailing: Text(
                        '${item.value}점',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (recommendedIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  '추천 운동',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: recommendedIds.map((id) {
                    final ex = Exercises.byId(id);
                    return Chip(
                      label: Text(ex.name),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: patientId == null
                      ? null
                      : () {
                    context.go('/exercise', extra: {
                      'patientId': patientId,
                      'affectedSide': affectedSide,
                      'fromScreening': true,
                    });
                  },
                  child: const Text('오늘의 운동 시작하기'),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: patientId == null
                      ? null
                      : () {
                    context.go('/exercise', extra: {
                      'patientId': patientId,
                      'affectedSide': affectedSide,
                      'fromScreening': true,
                    });
                  },
                  child: const Text('운동 선택으로 돌아가기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}