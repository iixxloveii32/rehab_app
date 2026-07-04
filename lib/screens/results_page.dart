import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';

import '../exercises/exercise_definitions.dart';
import '../models/session_log.dart';
import '../storage/isar_db.dart';

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

  List<SessionLog> sessionLogs = [];
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
      final data = extra is Map ? extra : null;

      patientId = (data?['patientId'] as int?) ?? -1;
      sessionUuid = (data?['sessionUuid'] as String?) ?? '';
      affectedSide = data?['affectedSide'] as String?;

      if (patientId < 0) throw Exception('patientId가 없습니다.');
      if (sessionUuid.isEmpty) throw Exception('sessionUuid가 없습니다.');

      final isar = IsarDB.instance;
      final logs = await isar.sessionLogs
          .filter()
          .patientIdEqualTo(patientId)
          .sessionUuidEqualTo(sessionUuid)
          .isReferenceEqualTo(false)
          .findAll();

      logs.sort((a, b) => a.timestampKst.compareTo(b.timestampKst));

      // 환자용 결과 화면에서는 같은 운동의 반복 로그를 모두 나열하지 않고
      // 운동별 최신 시도 1개만 대표값으로 표시한다.
      final latestByExercise = <int, SessionLog>{};
      for (final log in logs) {
        latestByExercise[log.exerciseId] = log;
      }

      sessionLogs = latestByExercise.values.toList()
        ..sort((a, b) => a.timestampKst.compareTo(b.timestampKst));

      totalExercises = sessionLogs.length;
      if (sessionLogs.isEmpty) {
        avgScore = 0;
        bestScore = 0;
      } else {
        final sum = sessionLogs.fold<int>(0, (v, e) => v + e.overall);
        avgScore = sum / sessionLogs.length;
        bestScore = sessionLogs.map((e) => e.overall).reduce((a, b) => a > b ? a : b);
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

  ExerciseDef _exercise(int id) => Exercises.byId(id);

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

  SessionLog? get _bestLog {
    if (sessionLogs.isEmpty) return null;
    final sorted = [...sessionLogs]..sort((a, b) => b.overall.compareTo(a.overall));
    return sorted.first;
  }

  SessionLog? get _lowestLog {
    if (sessionLogs.isEmpty) return null;
    final sorted = [...sessionLogs]..sort((a, b) => a.overall.compareTo(b.overall));
    return sorted.first;
  }

  String _affectedSideLabel() {
    if (affectedSide == 'L') return '좌측';
    if (affectedSide == 'R') return '우측';
    return '환측';
  }

  String _overallComment(double score) {
    if (score >= 85) return '오늘의 추천운동을 매우 안정적으로 수행했어요.';
    if (score >= 70) return '오늘의 추천운동을 잘 마쳤어요.';
    if (score >= 50) return '오늘 운동을 끝까지 수행했어요. 다음에는 조금 더 천천히 정확하게 해보세요.';
    return '오늘 운동을 완료했어요. 무리하지 말고 천천히 다시 연습해보세요.';
  }

  Color _scoreColor(int score) {
    if (score >= 85) return const Color(0xFF3FAE6F);
    if (score >= 70) return const Color(0xFF5B8DEF);
    if (score >= 50) return const Color(0xFFE0A63E);
    return const Color(0xFFE57373);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goToExerciseOrPatientList();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goToExerciseOrPatientList,
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
        body: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? _ErrorView(error: error!, onBack: _goToExerciseOrPatientList)
              : sessionLogs.isEmpty
              ? _EmptyView(
            onExercise: _goToExerciseOrPatientList,
            onPatientList: () => context.go('/patient-list'),
          )
              : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopResultCard(
                  totalExercises: totalExercises,
                  avgScore: avgScore,
                  bestLog: _bestLog,
                  lowestLog: _lowestLog,
                  affectedSideLabel: _affectedSideLabel(),
                  exerciseNameOf: (id) => _exercise(id).taskTitle,
                  comment: _overallComment(avgScore),
                ),
                const SizedBox(height: 12),
                _ExerciseCompactList(
                  logs: sessionLogs,
                  exerciseOf: _exercise,
                  scoreColor: _scoreColor,
                ),
                const SizedBox(height: 16),
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
                    onPressed: () => context.go('/patient-list'),
                    child: const Text('사용자 선택으로'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopResultCard extends StatelessWidget {
  final int totalExercises;
  final double avgScore;
  final SessionLog? bestLog;
  final SessionLog? lowestLog;
  final String affectedSideLabel;
  final String Function(int id) exerciseNameOf;
  final String comment;

  const _TopResultCard({
    required this.totalExercises,
    required this.avgScore,
    required this.bestLog,
    required this.lowestLog,
    required this.affectedSideLabel,
    required this.exerciseNameOf,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    final best = bestLog;
    final low = lowestLog;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘의 운동 완료',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            '$affectedSideLabel 상지 추천운동 $totalExercises가지를 마쳤어요.',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SummaryBox(label: '운동 수', value: '$totalExercises개')),
              const SizedBox(width: 8),
              Expanded(child: _SummaryBox(label: '평균 점수', value: '${avgScore.toStringAsFixed(1)}점')),
              const SizedBox(width: 8),
              Expanded(child: _SummaryBox(label: '최고 점수', value: '${best?.overall ?? 0}점')),
            ],
          ),
          if (best != null && low != null) ...[
            const SizedBox(height: 12),
            _InsightLine(label: '가장 잘한 운동', value: '${exerciseNameOf(best.exerciseId)} ${best.overall}점'),
            const SizedBox(height: 6),
            _InsightLine(label: '조금 더 연습할 운동', value: '${exerciseNameOf(low.exerciseId)} ${low.overall}점'),
          ],
          const SizedBox(height: 10),
          Text(
            comment,
            style: const TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _InsightLine extends StatelessWidget {
  final String label;
  final String value;

  const _InsightLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF455468)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ExerciseCompactList extends StatelessWidget {
  final List<SessionLog> logs;
  final ExerciseDef Function(int id) exerciseOf;
  final Color Function(int score) scoreColor;

  const _ExerciseCompactList({
    required this.logs,
    required this.exerciseOf,
    required this.scoreColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '운동별 결과',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...List.generate(logs.length, (index) {
            final log = logs[index];
            final ex = exerciseOf(log.exerciseId);
            return Padding(
              padding: EdgeInsets.only(bottom: index == logs.length - 1 ? 0 : 8),
              child: _ExerciseRow(
                index: index + 1,
                title: ex.taskTitle,
                subtitle: ex.name,
                score: log.overall,
                color: scoreColor(log.overall),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final int score;
  final Color color;

  const _ExerciseRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: const Color(0xFFEAF2FF), borderRadius: BorderRadius.circular(999)),
          child: Center(
            child: Text('$index', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF2F67B2))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              Text('$subtitle 운동', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5B6676))),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(999)),
          child: Text('$score점', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onBack;

  const _ErrorView({required this.error, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFE57373)),
          const SizedBox(height: 16),
          const Text('결과를 불러오지 못했습니다.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.4)),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onBack, child: const Text('운동 화면으로'))),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onExercise;
  final VoidCallback onPatientList;

  const _EmptyView({required this.onExercise, required this.onPatientList});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_outlined, size: 54, color: Color(0xFF5B8DEF)),
          const SizedBox(height: 16),
          const Text('저장된 운동 결과가 없습니다.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onExercise, child: const Text('운동 화면으로'))),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onPatientList, child: const Text('사용자 선택으로'))),
        ],
      ),
    );
  }
}
