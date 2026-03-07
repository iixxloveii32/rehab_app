import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

  int todayCount = 0;
  int todayBest = 0;
  double todayAvg = 0;

  final Map<int, _ExerciseSummary> byExercise = {
    for (var i = 0; i < 8; i++) i: _ExerciseSummary(),
  };

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
      if (patientId < 0) throw Exception('patientId가 없습니다.');

      final todayKey = _dateKey(DateTime.now());
      final isar = IsarDB.instance;

      final List<SessionLog> logs = await isar.sessionLogs
          .filter()
          .patientIdEqualTo(patientId)
          .dateKeyEqualTo(todayKey)
          .isReferenceEqualTo(false)
          .findAll();

      logs.sort((a, b) => b.timestampKst.compareTo(a.timestampKst));

      todayCount = logs.length;
      if (todayCount == 0) {
        todayBest = 0;
        todayAvg = 0;
      } else {
        int sum = 0;
        int best = 0;
        for (final l in logs) {
          sum += l.overall.toInt();
          if (l.overall > best) best = l.overall;
        }
        todayBest = best;
        todayAvg = sum / todayCount;
      }

      for (var i = 0; i < 8; i++) {
        byExercise[i] = _ExerciseSummary();
      }

      for (final l in logs) {
        final ex = l.exerciseId;
        final s = byExercise[ex] ?? _ExerciseSummary();

        s.count += 1;
        s.sumOverall += l.overall.toInt();
        if (l.overall > s.bestOverall) s.bestOverall = l.overall;

        byExercise[ex] = s;
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

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _exerciseName(int id) => Exercises.byId(id).name;

  String _scoreComment(double score) {
    if (score >= 80) return '좋아요';
    if (score >= 60) return '잘하고 있어요';
    if (score >= 40) return '조금 더 연습해볼까요';
    return '천천히 다시 해봐요';
  }

  Future<void> _exportCsv() async {
    try {
      final isar = IsarDB.instance;
      final logs = await isar.sessionLogs.where().findAll();

      if (logs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내보낼 데이터가 없습니다')),
        );
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln(
        'patientId,exerciseId,timestampKst,dateKey,overall,symmetry,timing,smoothness,compensation,rom,sessionUuid,appVersion,scoreSchemaVersion',
      );

      for (final l in logs) {
        buffer.writeln(
          '${l.patientId},${l.exerciseId},${l.timestampKst.toIso8601String()},${l.dateKey},${l.overall},${l.symmetry},${l.timing},${l.smoothness},${l.compensation},${l.rom},${l.sessionUuid},${l.appVersion},${l.scoreSchemaVersion}',
        );
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/rehab_export.csv');
      await file.writeAsString(buffer.toString(), flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '재활 훈련 데이터 CSV',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayKey = _dateKey(DateTime.now());
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;
    final patientIdFromRoute = data?['patientId'] as int?;
    final showBottomButton = !loading && error == null && patientIdFromRoute != null;

    final performedExercises = byExercise.entries
        .where((e) => e.value.count > 0)
        .toList()
      ..sort((a, b) => b.value.bestOverall.compareTo(a.value.bestOverall));

    return Scaffold(
      appBar: AppBar(
        title: const Text('훈련 결과'),
        actions: [
          IconButton(
            tooltip: '내보내기',
            onPressed: _exportCsv,
            icon: const Icon(Icons.upload_file),
          ),
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
          ? Center(child: Text('오류: $error'))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '오늘의 운동 결과',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              todayKey,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              count: todayCount,
              best: todayBest,
              avg: todayAvg,
            ),
            const SizedBox(height: 16),
            Text(
              _scoreComment(todayAvg),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '오늘 한 운동',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: performedExercises.isEmpty
                  ? const Center(
                child: Text('아직 수행한 운동이 없습니다.'),
              )
                  : ListView.separated(
                itemCount: performedExercises.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final entry = performedExercises[index];
                  final exerciseId = entry.key;
                  final s = entry.value;
                  final double avg = s.count == 0 ? 0.0 : s.sumOverall / s.count;

                  return _ExerciseResultCard(
                    title: _exerciseName(exerciseId),
                    count: s.count,
                    best: s.bestOverall,
                    avg: avg,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: showBottomButton
          ? SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => context.push(
                '/exercise',
                extra: {'patientId': patientIdFromRoute},
              ),
              child: const Text('다시 운동하기'),
            ),
          ),
        ),
      )
          : null,
    );
  }
}

class _ExerciseSummary {
  int count = 0;
  int sumOverall = 0;
  int bestOverall = 0;
}

class _SummaryCard extends StatelessWidget {
  final int count;
  final int best;
  final double avg;

  const _SummaryCard({
    required this.count,
    required this.best,
    required this.avg,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                label: '총 횟수',
                value: '$count',
              ),
            ),
            Expanded(
              child: _SummaryItem(
                label: '최고 점수',
                value: '$best점',
              ),
            ),
            Expanded(
              child: _SummaryItem(
                label: '평균 점수',
                value: '${avg.toStringAsFixed(1)}점',
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
  final String title;
  final int count;
  final int best;
  final double avg;

  const _ExerciseResultCard({
    required this.title,
    required this.count,
    required this.best,
    required this.avg,
  });

  String _shortComment(double avg) {
    if (avg >= 80) return '좋아요';
    if (avg >= 60) return '잘하고 있어요';
    if (avg >= 40) return '조금 더 연습해보세요';
    return '천천히 다시 해보세요';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '오늘 $count번 했어요\n최고 $best점 · 평균 ${avg.toStringAsFixed(1)}점 · ${_shortComment(avg)}',
          ),
        ),
      ),
    );
  }
}