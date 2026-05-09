import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';

import '../exercises/exercise_definitions.dart';
import '../models/session_log.dart';
import '../storage/isar_db.dart';
import '../ui/app_scaffold_body.dart';
import '../ui/responsive.dart';

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
  String? affectedSide;

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
      affectedSide = data?['affectedSide'] as String?;

      if (patientId < 0) {
        throw Exception('patientId가 없습니다.');
      }
      if (sessionUuid.isEmpty) {
        throw Exception('sessionUuid가 없습니다.');
      }

      final isar = IsarDB.instance;

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
          sum += l.overall;
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

  void _handleBack() {
    if (affectedSide != null && affectedSide!.isNotEmpty) {
      context.go('/exercise', extra: {
        'patientId': patientId,
        'affectedSide': affectedSide,
      });
    } else {
      context.go('/patient-list');
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

  Color _scoreColor(int score) {
    if (score >= 85) return const Color(0xFF3FAE6F);
    if (score >= 70) return const Color(0xFF5B8DEF);
    if (score >= 50) return const Color(0xFFE0A63E);
    return const Color(0xFFE57373);
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

  void _goToExerciseOrPatientList() {
    if (affectedSide != null && affectedSide!.isNotEmpty) {
      context.go('/exercise', extra: {
        'patientId': patientId,
        'affectedSide': affectedSide,
      });
    } else {
      context.go('/patient-list');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
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
              style: const TextStyle(fontSize: 16),
            ),
          ),
        )
            : todayLogs.isEmpty
            ? AppScaffoldBody(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.assignment_outlined,
                size: 72,
                color: Color(0xFF8A96A8),
              ),
              const SizedBox(height: 20),
              const Text(
                '오늘의 운동 결과를 찾을 수 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToExerciseOrPatientList,
                  child: const Text('운동 화면으로 돌아가기'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    context.go('/patient-list');
                  },
                  child: const Text('사용자 선택으로'),
                ),
              ),
            ],
          ),
        )
            : AppScaffoldBody(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CompletionCard(
                  totalExercises: totalExercises,
                  avgScore: avgScore,
                  bestScore: bestScore,
                  comment: _overallComment(avgScore),
                ),

                SizedBox(
                  height: Responsive.sectionSpacing(context),
                ),

                Text(
                  '운동별 결과',
                  style: Theme.of(context).textTheme.titleLarge,
                ),

                const SizedBox(height: 10),

                if (isTablet)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(
                      todayLogs.length,
                          (index) {
                        final log = todayLogs[index];

                        return SizedBox(
                          width:
                          (Responsive.maxContentWidth(context) -
                              12) /
                              2,
                          child: _ExerciseResultCard(
                            index: index + 1,
                            title: _exerciseName(log.exerciseId),
                            score: log.overall.toInt(),
                            symmetry: log.symmetry.toInt(),
                            timing: log.timing.toInt(),
                            smoothness: log.smoothness.toInt(),
                            compensation:
                            log.compensation.toInt(),
                            rom: log.rom.toInt(),
                            comment:
                            _exerciseComment(log.overall),
                            scoreColor:
                            _scoreColor(log.overall),
                          ),
                        );
                      },
                    ),
                  )
                else
                  ...List.generate(todayLogs.length, (index) {
                    final log = todayLogs[index];

                    return Padding(
                      padding:
                      const EdgeInsets.only(bottom: 12),
                      child: _ExerciseResultCard(
                        index: index + 1,
                        title: _exerciseName(log.exerciseId),
                        score: log.overall.toInt(),
                        symmetry: log.symmetry.toInt(),
                        timing: log.timing.toInt(),
                        smoothness: log.smoothness.toInt(),
                        compensation:
                        log.compensation.toInt(),
                        rom: log.rom.toInt(),
                        comment: _exerciseComment(log.overall),
                        scoreColor: _scoreColor(log.overall),
                      ),
                    );
                  }),

                if (_bestLog != null && _lowestLog != null) ...[
                  const SizedBox(height: 12),
                  _InsightCard(
                    bestTitle:
                    _exerciseName(_bestLog!.exerciseId),
                    bestScore: _bestLog!.overall,
                    needTitle:
                    _exerciseName(_lowestLog!.exerciseId),
                    needScore: _lowestLog!.overall,
                  ),
                ],

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _goToExerciseOrPatientList,
                    child: const Text('다시 운동하기'),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      context.go('/patient-list');
                    },
                    child: const Text('사용자 선택으로'),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  final int totalExercises;
  final double avgScore;
  final int bestScore;
  final String comment;

  const _CompletionCard({
    required this.totalExercises,
    required this.avgScore,
    required this.bestScore,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.isTablet(context) ? 24 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘의 운동 완료',
            style: TextStyle(
              fontSize: Responsive.largeTitleFontSize(context),
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalExercises가지 운동을 마쳤어요.',
            style: TextStyle(
              fontSize: Responsive.bodyFontSize(context) + 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryValueBox(
                  label: '운동 수',
                  value: '$totalExercises개',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryValueBox(
                  label: '평균 점수',
                  value: '${avgScore.toStringAsFixed(1)}점',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryValueBox(
                  label: '최고 점수',
                  value: '$bestScore점',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            comment,
            style: TextStyle(
              fontSize: Responsive.bodyFontSize(context),
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryValueBox extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryValueBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: Responsive.isTablet(context) ? 16 : 14,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.bodyFontSize(context) - 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.bodyFontSize(context) + 2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
  final Color scoreColor;

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
    required this.scoreColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(Responsive.isTablet(context) ? 18 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$index. $title',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$score점',
                    style: TextStyle(
                      fontSize: Responsive.bodyFontSize(context) - 1,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              comment,
              style: TextStyle(
                fontSize: Responsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ScoreChip(label: '좌우 균형', value: symmetry),
                _ScoreChip(label: '속도 맞추기', value: timing),
                _ScoreChip(label: '부드러움', value: smoothness),
                _ScoreChip(label: '몸통 안정성', value: compensation),
                _ScoreChip(label: '동작 범위', value: rom),
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
      label: Text(
        '$label $value점',
        style: TextStyle(
          fontSize: Responsive.bodyFontSize(context) - 2,
          fontWeight: FontWeight.w600,
        ),
      ),
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
      child: Padding(
        padding: EdgeInsets.all(Responsive.isTablet(context) ? 20 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '한눈에 보기',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7EE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '가장 잘한 운동: $bestTitle ($bestScore점)',
                style: TextStyle(
                  fontSize: Responsive.bodyFontSize(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '조금 더 연습할 운동: $needTitle ($needScore점)',
                style: TextStyle(
                  fontSize: Responsive.bodyFontSize(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}