import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';

import '../models/patient.dart';
import '../models/session_log.dart';
import '../storage/isar_db.dart';
import '../ui/app_scaffold_body.dart';
import '../ui/responsive.dart';

class ExerciseHistoryPage extends StatefulWidget {
  const ExerciseHistoryPage({super.key});

  @override
  State<ExerciseHistoryPage> createState() => _ExerciseHistoryPageState();
}

class _ExerciseHistoryPageState extends State<ExerciseHistoryPage> {
  bool _loading = true;
  String? _error;
  Patient? _patient;
  List<_SessionSummary> _sessions = [];
  _OverallSummary? _overall;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Map? _routeExtra(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    return extra is Map ? extra : null;
  }

  Future<void> _load() async {
    try {
      final data = _routeExtra(context);
      final patientId = data?['patientId'] as int?;

      if (patientId == null) {
        throw Exception('사용자 정보가 전달되지 않았습니다.');
      }

      final isar = IsarDB.instance;
      final patient = await isar.patients.get(patientId);
      if (patient == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      final logs = await isar.sessionLogs
          .filter()
          .patientIdEqualTo(patientId)
          .isReferenceEqualTo(false)
          .findAll();

      logs.sort((a, b) => a.timestampKst.compareTo(b.timestampKst));

      final sessions = _buildSessionSummaries(logs);
      final overall = _buildOverallSummary(sessions, logs);

      if (!mounted) return;
      setState(() {
        _patient = patient;
        _sessions = sessions;
        _overall = overall;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<_SessionSummary> _buildSessionSummaries(List<SessionLog> logs) {
    final grouped = <String, List<SessionLog>>{};

    for (final log in logs) {
      final sessionId = log.sessionUuid.trim().isEmpty
          ? 'no_session_${log.dateKey}'
          : log.sessionUuid.trim();
      final key = '${log.dateKey}|$sessionId';
      grouped.putIfAbsent(key, () => <SessionLog>[]).add(log);
    }

    final summaries = <_SessionSummary>[];

    for (final entry in grouped.entries) {
      final sessionLogs = [...entry.value]
        ..sort((a, b) => a.timestampKst.compareTo(b.timestampKst));

      // 같은 세션에서 같은 운동을 반복한 경우, 화면 요약은 운동별 최신 결과 1개만 표시한다.
      final latestByExercise = <int, SessionLog>{};
      for (final log in sessionLogs) {
        final prev = latestByExercise[log.exerciseId];
        if (prev == null || log.timestampKst.isAfter(prev.timestampKst)) {
          latestByExercise[log.exerciseId] = log;
        }
      }

      final representativeLogs = latestByExercise.values.toList()
        ..sort((a, b) => a.timestampKst.compareTo(b.timestampKst));

      final avg = representativeLogs.isEmpty
          ? 0
          : (representativeLogs.map((e) => e.overall).reduce((a, b) => a + b) /
          representativeLogs.length)
          .round();

      final best = representativeLogs.isEmpty
          ? null
          : representativeLogs.reduce((a, b) => a.overall >= b.overall ? a : b);
      final weakest = representativeLogs.isEmpty
          ? null
          : representativeLogs.reduce((a, b) => a.overall <= b.overall ? a : b);

      summaries.add(
        _SessionSummary(
          dateKey: sessionLogs.first.dateKey,
          sessionUuid: sessionLogs.first.sessionUuid,
          startedAt: sessionLogs.first.timestampKst,
          endedAt: sessionLogs.last.timestampKst,
          completedExerciseCount: representativeLogs.length,
          averageScore: avg,
          bestExerciseName: best == null ? '-' : _exerciseName(best.exerciseId),
          bestScore: best?.overall ?? 0,
          weakestExerciseName: weakest == null ? '-' : _exerciseName(weakest.exerciseId),
          weakestScore: weakest?.overall ?? 0,
          exerciseResults: representativeLogs
              .map(
                (e) => _ExerciseResult(
              exerciseId: e.exerciseId,
              exerciseName: _exerciseName(e.exerciseId),
              score: e.overall,
              timestamp: e.timestampKst,
            ),
          )
              .toList(),
        ),
      );
    }

    summaries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return summaries;
  }

  _OverallSummary _buildOverallSummary(
      List<_SessionSummary> sessions,
      List<SessionLog> logs,
      ) {
    if (sessions.isEmpty) {
      return const _OverallSummary(
        totalDays: 0,
        totalSessions: 0,
        totalExercises: 0,
        overallAverage: 0,
        latestDateLabel: '-',
      );
    }

    final daySet = sessions.map((e) => e.dateKey).toSet();
    final totalExercises = sessions.fold<int>(
      0,
          (sum, s) => sum + s.completedExerciseCount,
    );
    final allScores = sessions.expand((s) => s.exerciseResults).map((e) => e.score).toList();
    final avg = allScores.isEmpty
        ? 0
        : (allScores.reduce((a, b) => a + b) / allScores.length).round();

    return _OverallSummary(
      totalDays: daySet.length,
      totalSessions: sessions.length,
      totalExercises: totalExercises,
      overallAverage: avg,
      latestDateLabel: _dateLabel(sessions.first.startedAt),
    );
  }

  String _exerciseName(int id) {
    switch (id) {
      case 0:
        return '팔 앞으로 들기';
      case 1:
        return '팔 옆으로 들기';
      case 2:
        return '머리 만지기';
      case 3:
        return '허리 뒤로 손 가져가기';
      case 4:
        return '앞으로 손 뻗기';
      case 5:
        return '옆으로 손 뻗기';
      case 6:
        return '팔 굽히기';
      case 7:
        return '팔 펴기';
      default:
        return '운동';
    }
  }

  String _dateLabel(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _timeLabel(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _goBack() {
    context.go('/patient-list');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('운동기록'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
          actions: [
            IconButton(
              tooltip: '새로고침',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('오류: $_error'),
          ),
        )
            : AppScaffoldBody(
          child: _sessions.isEmpty ? _emptyView() : _content(),
        ),
      ),
    );
  }

  Widget _content() {
    final patient = _patient;
    final overall = _overall;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: 20 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          _topSummaryCard(patient, overall),
          const SizedBox(height: 16),
          const Text(
            '세션별 기록',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          ..._sessions.map(_sessionCard),
        ],
      ),
    );
  }

  Widget _topSummaryCard(Patient? patient, _OverallSummary? overall) {
    final name = patient?.name ?? '사용자';
    final summary = overall ??
        const _OverallSummary(
          totalDays: 0,
          totalSessions: 0,
          totalExercises: 0,
          overallAverage: 0,
          latestDateLabel: '-',
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD4E4FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name님의 운동기록',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '완료되어 저장된 운동 결과만 표시됩니다.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5B6676),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  label: '운동일수',
                  value: '${summary.totalDays}일',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryMetric(
                  label: '완료운동',
                  value: '${summary.totalExercises}개',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryMetric(
                  label: '평균점수',
                  value: '${summary.overallAverage}점',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.event_available, size: 18, color: Color(0xFF2F67B2)),
              const SizedBox(width: 6),
              Text(
                '최근 운동일: ${summary.latestDateLabel}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2F67B2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5B6676),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F2A37),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(_SessionSummary session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateLabel(session.startedAt),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_timeLabel(session.startedAt)} 시작 · ${session.completedExerciseCount}개 완료',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5B6676),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '평균 ${session.averageScore}점',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2F67B2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniInfo(
                  label: '가장 좋음',
                  value: '${session.bestExerciseName} ${session.bestScore}점',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniInfo(
                  label: '더 연습',
                  value: '${session.weakestExerciseName} ${session.weakestScore}점',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...session.exerciseResults.map(_exerciseRow),
        ],
      ),
    );
  }

  Widget _miniInfo({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5B6676),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2A37),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exerciseRow(_ExerciseResult result) {
    final score = result.score.clamp(0, 100);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              result.exerciseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: score / 100.0,
                minHeight: 8,
                backgroundColor: const Color(0xFFE5EAF2),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              '$score점',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2F67B2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Responsive.isTablet(context) ? 32 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history,
              size: 76,
              color: Color(0xFF8A96A8),
            ),
            const SizedBox(height: 18),
            const Text(
              '아직 저장된 운동기록이 없습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '운동을 완료하고 분석 결과가 저장되면\n이 화면에서 날짜별 기록을 볼 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5B6676),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('사용자 선택으로 돌아가기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallSummary {
  final int totalDays;
  final int totalSessions;
  final int totalExercises;
  final int overallAverage;
  final String latestDateLabel;

  const _OverallSummary({
    required this.totalDays,
    required this.totalSessions,
    required this.totalExercises,
    required this.overallAverage,
    required this.latestDateLabel,
  });
}

class _SessionSummary {
  final String dateKey;
  final String sessionUuid;
  final DateTime startedAt;
  final DateTime endedAt;
  final int completedExerciseCount;
  final int averageScore;
  final String bestExerciseName;
  final int bestScore;
  final String weakestExerciseName;
  final int weakestScore;
  final List<_ExerciseResult> exerciseResults;

  const _SessionSummary({
    required this.dateKey,
    required this.sessionUuid,
    required this.startedAt,
    required this.endedAt,
    required this.completedExerciseCount,
    required this.averageScore,
    required this.bestExerciseName,
    required this.bestScore,
    required this.weakestExerciseName,
    required this.weakestScore,
    required this.exerciseResults,
  });
}

class _ExerciseResult {
  final int exerciseId;
  final String exerciseName;
  final int score;
  final DateTime timestamp;

  const _ExerciseResult({
    required this.exerciseId,
    required this.exerciseName,
    required this.score,
    required this.timestamp,
  });
}
