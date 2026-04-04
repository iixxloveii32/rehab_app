import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../exercises/exercise_definitions.dart';
import '../ui/app_scaffold_body.dart';
import '../ui/responsive.dart';
import 'screening_plan.dart';

class ScreeningResultPage extends StatelessWidget {
  const ScreeningResultPage({super.key});

  void _handleBack(BuildContext context, int? patientId, String affectedSide) {
    context.go('/exercise', extra: {
      'patientId': patientId,
      'affectedSide': affectedSide,
      'fromScreening': true,
    });
  }

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

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF3FAE6F);
    if (score >= 60) return const Color(0xFF5B8DEF);
    return const Color(0xFFE0A63E);
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;

    final int? patientId = data?['patientId'] as int?;
    final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';

    final Map<String, int> scores =
        (data?['screeningScores'] as Map?)?.map((k, v) => MapEntry('$k', v as int)) ??
            <String, int>{};

    final recommendedIds = recommendedExerciseIdsFromScores(scores);
    final summary = screeningSummaryText(scores);

    final sortedScores = scores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final isTablet = Responsive.isTablet(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack(context, patientId, affectedSide);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBack(context, patientId, affectedSide),
          ),
          title: const Text('상지 기능 평가 결과'),
        ),
        body: AppScaffoldBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScreeningSummaryCard(summary: summary),
              SizedBox(height: Responsive.sectionSpacing(context)),
              Text(
                '동작별 결과',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: sortedScores.isEmpty
                    ? const Center(
                  child: Text(
                    '평가 결과가 없습니다.',
                    style: TextStyle(fontSize: 17),
                  ),
                )
                    : ListView(
                  children: [
                    if (isTablet)
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: sortedScores.map((item) {
                          return SizedBox(
                            width: (Responsive.maxContentWidth(context) - 12) / 2,
                            child: _ScoreResultCard(
                              title: _labelForKey(item.key),
                              score: item.value,
                              comment: _scoreComment(item.value),
                              color: _scoreColor(item.value),
                            ),
                          );
                        }).toList(),
                      )
                    else
                      ...sortedScores.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ScoreResultCard(
                            title: _labelForKey(item.key),
                            score: item.value,
                            comment: _scoreComment(item.value),
                            color: _scoreColor(item.value),
                          ),
                        );
                      }),
                    if (recommendedIds.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '추천 운동',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      _RecommendedExerciseCard(
                        recommendedIds: recommendedIds,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
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

class _ScreeningSummaryCard extends StatelessWidget {
  final String summary;

  const _ScreeningSummaryCard({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.isTablet(context) ? 24 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '평가가 완료되었습니다',
            style: TextStyle(
              fontSize: Responsive.largeTitleFontSize(context),
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '현재 상태를 바탕으로 오늘의 운동을 추천해 드릴게요.',
            style: TextStyle(
              fontSize: Responsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: TextStyle(
              fontSize: Responsive.bodyFontSize(context),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreResultCard extends StatelessWidget {
  final String title;
  final int score;
  final String comment;
  final Color color;

  const _ScoreResultCard({
    required this.title,
    required this.score,
    required this.comment,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(Responsive.isTablet(context) ? 18 : 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comment,
                    style: TextStyle(
                      fontSize: Responsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$score점',
                style: TextStyle(
                  fontSize: Responsive.bodyFontSize(context) - 1,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedExerciseCard extends StatelessWidget {
  final List<int> recommendedIds;

  const _RecommendedExerciseCard({
    required this.recommendedIds,
  });

  @override
  Widget build(BuildContext context) {
    final names = recommendedIds.map((id) => Exercises.byId(id).name).toList();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(Responsive.isTablet(context) ? 20 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '오늘 추천 운동',
              style: TextStyle(
                fontSize: Responsive.bodyFontSize(context) + 2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(names.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${index + 1}. ${names[index]}',
                    style: TextStyle(
                      fontSize: Responsive.bodyFontSize(context) + 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Text(
              '아래 버튼을 누르면 오늘의 추천 운동을 시작할 수 있어요.',
              style: TextStyle(
                fontSize: Responsive.bodyFontSize(context) - 1,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}