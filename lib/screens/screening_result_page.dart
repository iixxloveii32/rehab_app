import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';

import '../models/session_log.dart';
import '../storage/isar_db.dart';

class ScreeningResultPage extends StatefulWidget {
  const ScreeningResultPage({super.key});

  @override
  State<ScreeningResultPage> createState() => _ScreeningResultPageState();
}

class _ScreeningResultPageState extends State<ScreeningResultPage> {
  bool _loading = true;
  String? _error;

  int? _patientId;
  String _affectedSide = 'L';
  String? _screeningSessionUuid;

  List<SessionLog> _logs = [];
  List<int> _recommendedIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final extra = GoRouterState.of(context).extra;
      final data = (extra is Map) ? extra : null;

      _patientId = data?['patientId'] as int?;
      _affectedSide = (data?['affectedSide'] as String?) ?? 'L';
      _screeningSessionUuid = data?['screeningSessionUuid'] as String?;

      if (_patientId == null || _screeningSessionUuid == null) {
        throw Exception('스크리닝 결과를 불러올 수 없습니다.');
      }

      final isar = IsarDB.instance;
      final allLogs = await isar.sessionLogs.where().anyId().findAll();

      _logs = allLogs
          .where((log) =>
      log.patientId == _patientId &&
          log.sessionUuid == _screeningSessionUuid &&
          log.isReference == false)
          .toList();

      _logs.sort((a, b) => a.overall.compareTo(b.overall));

      _recommendedIds = _logs.take(3).map((e) => e.exerciseId).toList();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
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

  String _recommendMessage(int exerciseId) {
    switch (exerciseId) {
      case 0:
        return '팔을 앞으로 드는 기능이 다소 부족하여 팔 앞으로 들기 운동을 추천합니다.';
      case 1:
        return '팔을 옆으로 드는 기능이 다소 부족하여 팔 옆으로 들기 운동을 추천합니다.';
      case 2:
        return '머리 쪽으로 손을 가져가는 기능이 다소 부족하여 머리 만지기 운동을 추천합니다.';
      case 3:
        return '손을 허리 뒤로 가져가는 기능이 다소 부족하여 허리 뒤로 손 가져가기 운동을 추천합니다.';
      case 4:
        return '앞쪽 목표를 향해 손을 뻗는 기능이 다소 부족하여 앞으로 손 뻗기 운동을 추천합니다.';
      case 5:
        return '옆쪽 목표를 향해 손을 뻗는 기능이 다소 부족하여 옆으로 손 뻗기 운동을 추천합니다.';
      case 6:
        return '팔을 굽히는 기능이 다소 부족하여 팔 굽히기 운동을 추천합니다.';
      case 7:
        return '팔을 펴는 기능이 다소 부족하여 팔 펴기 운동을 추천합니다.';
      default:
        return '현재 상태를 바탕으로 이 운동을 추천합니다.';
    }
  }

  String _summaryTitle(double avg) {
    if (avg >= 80) return '현재 상지 기능이 비교적 좋습니다.';
    if (avg >= 60) return '일부 기능은 양호하지만 추가 연습이 필요합니다.';
    return '상지 기능 보완이 필요한 상태입니다.';
  }

  double get _avgScore {
    if (_logs.isEmpty) return 0;
    final sum = _logs.fold<int>(0, (prev, e) => prev + e.overall);
    return sum / _logs.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('평가 결과')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('오류: $_error'),
          ),
        )
            : Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _summaryTitle(_avgScore),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '평균 점수 ${_avgScore.toStringAsFixed(1)}점',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),

              const Text(
                '부족한 기능과 추천 운동',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView.separated(
                  itemCount: _recommendedIds.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final id = _recommendedIds[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '추천 ${index + 1}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _exerciseName(id),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _recommendMessage(id),
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              if (_recommendedIds.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      final routineIds = List<int>.from(_recommendedIds);

                      context.go('/record', extra: {
                        'patientId': _patientId,
                        'exerciseId': routineIds.first,
                        'sessionUuid': DateTime.now().microsecondsSinceEpoch.toString(),
                        'affectedSide': _affectedSide,
                        'routineExerciseIds': routineIds,
                        'routineIndex': 0,
                        'fromRoutine': true,
                      });
                    },
                    child: const Text('오늘의 루틴 시작'),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    context.go('/exercise', extra: {
                      'patientId': _patientId,
                      'affectedSide': _affectedSide,
                      'fromScreening': true,
                    });
                  },
                  child: const Text('운동 선택 화면으로'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}