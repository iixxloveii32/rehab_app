import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import '../storage/isar_db.dart';
import '../models/session_log.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  bool loading = true;
  String? error;

  int patientId = -1;

  // 오늘 전체 요약
  int todayCount = 0;
  int todayBest = 0;
  double todayAvg = 0;

  // 동작별 요약 (0~7)
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

      // 1) 오늘 환자 세션 로그 전부 가져오기 (정렬은 Dart에서)
      final List<SessionLog> logs = await isar.sessionLogs
          .filter()
          .patientIdEqualTo(patientId)
          .dateKeyEqualTo(todayKey)
          .isReferenceEqualTo(false)
          .findAll();

// 최신순 정렬 (timestampKst 내림차순)
      logs.sort((a, b) => b.timestampKst.compareTo(a.timestampKst));

      // 2) 전체 요약 계산
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

      // 3) 동작별 best/avg/count + (서브 best 2개만)
      for (var i = 0; i < 8; i++) {
        byExercise[i] = _ExerciseSummary(); // reset
      }

      for (final l in logs) {
        final ex = l.exerciseId;
        final s = byExercise[ex] ?? _ExerciseSummary();

        s.count += 1;
        s.sumOverall += l.overall.toInt();
        if (l.overall > s.bestOverall) s.bestOverall = l.overall;

        // 서브는 best 기준으로만 MVP에 노출(연구용 full export는 나중)
        if (l.symmetry > s.bestSymmetry) s.bestSymmetry = l.symmetry;
        if (l.compensation > s.bestCompensation) s.bestCompensation = l.compensation;

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

  String _exerciseName(int id) {
    // TODO: 나중에 ExerciseDefinition으로 교체
    const names = [
      '전방 거상',
      '외전',
      '팔꿈치 굴곡/신전',
      '전완 회내/회외',
      '손목 굴곡/신전',
      '그립(주먹/펴기)',
      '엄지-검지 집기',
      '양손 과제',
    ];
    if (id < 0 || id >= names.length) return '운동 $id';
    return names[id];
  }

  @override
  Widget build(BuildContext context) {
    final todayKey = _dateKey(DateTime.now());
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;
    final patientId = data?['patientId'] as int?;

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
            Text('오늘($todayKey)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _SummaryCard(
              count: todayCount,
              best: todayBest,
              avg: todayAvg,
            ),
            const SizedBox(height: 16),
            Text('동작별', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: 8,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = byExercise[i] ?? _ExerciseSummary();
                  final avg = s.count == 0 ? 0 : (s.sumOverall / s.count);
                  return ListTile(
                    title: Text(_exerciseName(i)),
                    subtitle: Text(
                      '횟수 ${s.count} | best ${s.bestOverall} | avg ${avg.toStringAsFixed(1)}'
                          ' | sym best ${s.bestSymmetry} | comp best ${s.bestCompensation}',
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: patientId == null
                    ? null
                    : () => context.go('/exercise', extra: {'patientId': patientId}),
                child: const Text('다시 운동하기 (동작 선택)'),
              ),
            ),
          ],
        ),
      ),
    );
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
          'patientId,exerciseId,timestampKst,dateKey,overall,symmetry,timing,smoothness,compensation,rom,sessionUuid,appVersion,scoreSchemaVersion');

      for (final l in logs) {
        buffer.writeln(
            '${l.patientId},${l.exerciseId},${l.timestampKst.toIso8601String()},${l.dateKey},${l.overall},${l.symmetry},${l.timing},${l.smoothness},${l.compensation},${l.rom},${l.sessionUuid},${l.appVersion},${l.scoreSchemaVersion}');
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
}

class _ExerciseSummary {
  int count = 0;
  int sumOverall = 0;
  int bestOverall = 0;
  int bestSymmetry = 0;
  int bestCompensation = 0;
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: Text('총 횟수\n$count', textAlign: TextAlign.center)),
            Expanded(child: Text('최고점\n$best', textAlign: TextAlign.center)),
            Expanded(child: Text('평균\n${avg.toStringAsFixed(1)}', textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}