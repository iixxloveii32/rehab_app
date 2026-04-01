import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';

import '../exercises/exercise_definitions.dart';
import '../models/session_log.dart';
import '../storage/isar_db.dart';

class ExerciseSelectPage extends StatefulWidget {
  const ExerciseSelectPage({super.key});

  @override
  State<ExerciseSelectPage> createState() => _ExerciseSelectPageState();
}

class _ExerciseSelectPageState extends State<ExerciseSelectPage> {
  List<int> _recommendedIds = [];
  bool _loadingRecommendations = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadRecommendedExercises();
      if (!mounted) return;
      setState(() {
        _loadingRecommendations = false;
      });
    });
  }

  Future<void> _loadRecommendedExercises() async {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;
    final int? patientId = data?['patientId'] as int?;

    if (patientId == null) {
      if (!mounted) return;
      setState(() {
        _recommendedIds = [];
      });
      return;
    }

    try {
      final isar = IsarDB.instance;
      final List<SessionLog> allLogs = await isar.sessionLogs.where().findAll();

      final screeningLogs = allLogs
          .where(
            (log) =>
        log.patientId == patientId &&
            log.sessionUuid.startsWith('screening_') &&
            log.isReference == false,
      )
          .toList();

      if (screeningLogs.isEmpty) {
        if (!mounted) return;
        setState(() {
          _recommendedIds = [];
        });
        return;
      }

      screeningLogs.sort((a, b) => b.timestampKst.compareTo(a.timestampKst));
      final latestScreeningSessionUuid = screeningLogs.first.sessionUuid;

      final latestScreeningLogs = screeningLogs
          .where((log) => log.sessionUuid == latestScreeningSessionUuid)
          .toList();

      latestScreeningLogs.sort((a, b) => a.overall.compareTo(b.overall));

      final recommended = latestScreeningLogs
          .map((e) => e.exerciseId)
          .toSet()
          .take(3)
          .toList();

      if (!mounted) return;
      setState(() {
        _recommendedIds = recommended;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recommendedIds = [];
      });
    }
  }

  void _startTodayRoutine(int? patientId, String affectedSide) {
    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 사용자를 선택해 주세요.')),
      );
      return;
    }

    if (_recommendedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추천 운동이 없습니다. 먼저 현재 상태 평가를 진행해 주세요.')),
      );
      return;
    }

    final sessionUuid = DateTime.now().microsecondsSinceEpoch.toString();

    context.go('/record', extra: {
      'patientId': patientId,
      'exerciseId': _recommendedIds.first,
      'sessionUuid': sessionUuid,
      'affectedSide': affectedSide,
      'routineExerciseIds': _recommendedIds,
      'routineIndex': 0,
      'fromRoutine': true,
    });
  }

  Widget _screeningCard(
      BuildContext context,
      int? patientId,
      String? affectedSide,
      ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await context.push('/screening', extra: {
            'patientId': patientId,
            'affectedSide': affectedSide,
          });

          if (mounted) {
            await _loadRecommendedExercises();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_turned_in_outlined),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '현재 상태 평가하기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '간단한 동작 테스트로 현재 상지 기능을 확인해요.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  int? _recommendRank(int exerciseId) {
    final index = _recommendedIds.indexOf(exerciseId);
    if (index == -1) return null;
    return index + 1;
  }

  Color _recommendBadgeColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _recommendBadge(int rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _recommendBadgeColor(rank).withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _recommendBadgeColor(rank).withOpacity(0.35),
        ),
      ),
      child: Text(
        '추천 $rank',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: _recommendBadgeColor(rank),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;

    final int? patientId = data?['patientId'] as int?;
    final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';

    final items = Exercises.list;

    return Scaffold(
      appBar: AppBar(title: const Text('운동 선택')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _screeningCard(context, patientId, affectedSide),
            const SizedBox(height: 16),
            if (_loadingRecommendations)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '추천 운동을 불러오는 중입니다.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (_recommendedIds.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '추천 운동이 표시되어 있어요. 오늘의 운동을 바로 시작할 수 있어요.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _startTodayRoutine(patientId, affectedSide),
                  child: const Text('오늘의 운동 시작하기'),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '원하는 운동을 선택해서 바로 시작할 수 있어요.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              '운동 목록',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final it = items[i];
                  final rank = _recommendRank(it.id);

                  return ListTile(
                    tileColor: rank != null
                        ? Colors.blue.shade50
                        : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(it.name)),
                        if (rank != null) _recommendBadge(rank),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(it.desc),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final sessionUuid =
                      DateTime.now().microsecondsSinceEpoch.toString();

                      context.go('/record', extra: {
                        'patientId': patientId,
                        'exerciseId': it.id,
                        'sessionUuid': sessionUuid,
                        'affectedSide': affectedSide,
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