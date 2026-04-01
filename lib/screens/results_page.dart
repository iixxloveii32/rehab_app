import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../exercises/exercise_definitions.dart';
import '../models/session_log.dart';
import '../storage/isar_db.dart';
import 'package:isar/isar.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  bool loading = true;
  String? error;

  int patientId = -1;
  String sessionUuid = '';

  List<SessionLog> todayLogs = [];

  int totalExercises = 0;
  int bestScore = 0;
  double avgScore = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final extra = GoRouterState.of(context).extra;
      final data = (extra is Map) ? extra : null;

      patientId = (data?['patientId'] as int?) ?? -1;
      sessionUuid = (data?['sessionUuid'] as String?) ?? '';

      if (patientId < 0) {
        throw Exception('patientId가 없습니다.');
      }
      if (sessionUuid.isEmpty) {
        throw Exception('sessionUuid가 없습니다.');
      }

      final isar = IsarDB.instance;

      final allLogs = await isar.sessionLogs.where().anyId().findAll();

      final logs = await isar.sessionLogs
          .filter()
          .patientIdEqualTo(patientId)
          .sessionUuidEqualTo(sessionUuid)
          .isReferenceEqualTo(false)
          .findAll();

      logs.sort((a, b) => a.timestampKst.compareTo(b.timestampKst));

      todayLogs = logs;
      totalExercises = logs.length;

      if (logs.isEmpty) {
        bestScore = 0;
        avgScore = 0.0;
      } else {
        int sum = 0;
        int best = 0;

        for (final l in logs) {
          sum = sum + l.overall;
          if (l.overall > best) {
            best = l.overall;
          }
        }

        bestScore = best;
        avgScore = sum / logs.length;
      }

      if (!mounted) return;
      setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  String _exerciseName(int id) {
    final ex = Exercises.byId(id);
    return ex.name;
  }

  String _overallComment(double score) {
    if (score >= 85) return '아주 좋아요. 오늘의 운동을 정말 잘 마쳤어요.';
    if (score >= 70) return '좋아요. 꾸준히 하면 더 좋아질 수 있어요.';
    if (score >= 50) return '잘하고 있어요. 천천히 정확하게 반복해보세요.';
    return '괜찮아요. 무리하지 말고 천천히 다시 연습해보세요.';
  }

  String _exerciseComment(int score) {
    if (score >= 85) return '매우 좋음';
    if (score >= 70) return '좋음';
    if (score >= 50) return '보통';
    return '조금 더 연습해봐요';
  }

  SessionLog? get _bestLog {
    if (todayLogs.isEmpty) return null;
    final sorted = [...todayLogs]..sort((a, b) => b.overall.compareTo(a.overall));
    return sorted.first;
  }

  SessionLog? get _lowestLog {
    if (todayLogs.isEmpty) return null;
    final sorted = [...todayLogs]..sort((a, b) => a.overall.compareTo(b.overall));
    return sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;
    final patientIdFromRoute = data?['patientId'] as int?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 운동 결과'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '오류: $error',
            textAlign: TextAlign.center,
          ),
        ),
      )
          : todayLogs.isEmpty
          ? const Center(
        child: Text('오늘의 운동 결과를 찾을 수 없습니다.'),
      )
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘의 운동 완료',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$totalExercises가지 운동을 마쳤어요.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              _TodaySummaryCard(
                totalExercises: totalExercises,
                avgScore: avgScore,
                bestScore: bestScore,
              ),

              const SizedBox(height: 16),

              Text(
                _overallComment(avgScore),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                '운동별 결과',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: ListView.separated(
                  itemCount: todayLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final log = todayLogs[index];
                    return _ExerciseResultCard(
                      index: index + 1,
                      title: _exerciseName(log.exerciseId),
                      score: log.overall.toInt(),
                      symmetry: log.symmetry.toInt(),
                      timing: log.timing.toInt(),
                      smoothness: log.smoothness.toInt(),
                      compensation: log.compensation.toInt(),
                      rom: log.rom.toInt(),
                      comment: _exerciseComment(log.overall),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              if (_bestLog != null && _lowestLog != null)
                _InsightCard(
                  bestTitle: _exerciseName(_bestLog!.exerciseId),
                  bestScore: _bestLog!.overall,
                  needTitle: _exerciseName(_lowestLog!.exerciseId),
                  needScore: _lowestLog!.overall,
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: (patientIdFromRoute != null && !loading && error == null)
          ? SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    context.go('/exercise', extra: {
                      'patientId': patientIdFromRoute,
                    });
                  },
                  child: const Text('다시 운동하기'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    context.go('/', extra: {
                      'patientId': patientIdFromRoute,
                    });
                  },
                  child: const Text('처음 화면으로'),
                ),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  final int totalExercises;
  final double avgScore;
  final int bestScore;

  const _TodaySummaryCard({
    required this.totalExercises,
    required this.avgScore,
    required this.bestScore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                label: '운동 수',
                value: '$totalExercises개',
              ),
            ),
            Expanded(
              child: _SummaryItem(
                label: '평균 점수',
                value: '${avgScore.toStringAsFixed(1)}점',
              ),
            ),
            Expanded(
              child: _SummaryItem(
                label: '최고 점수',
                value: '$bestScore점',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ExerciseResultCard extends StatelessWidget {
  final int index;
  final String title;
  final int score;
  final int symmetry;
  final int timing;
  final int smoothness;
  final int compensation;
  final int rom;
  final String comment;

  const _ExerciseResultCard({
    required this.index,
    required this.title,
    required this.score,
    required this.symmetry,
    required this.timing,
    required this.smoothness,
    required this.compensation,
    required this.rom,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$index. $title',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '총점: $score점 · $comment',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ScoreChip(label: '대칭성', value: symmetry),
                _ScoreChip(label: '타이밍', value: timing),
                _ScoreChip(label: '부드러움', value: smoothness),
                _ScoreChip(label: '보상억제', value: compensation),
                _ScoreChip(label: '가동범위', value: rom),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final int value;

  const _ScoreChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label $value점'),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String bestTitle;
  final int bestScore;
  final String needTitle;
  final int needScore;

  const _InsightCard({
    required this.bestTitle,
    required this.bestScore,
    required this.needTitle,
    required this.needScore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '한눈에 보기',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('가장 잘한 운동: $bestTitle ($bestScore점)'),
            const SizedBox(height: 4),
            Text('조금 더 연습할 운동: $needTitle ($needScore점)'),
          ],
        ),
      ),
    );
  }
}
