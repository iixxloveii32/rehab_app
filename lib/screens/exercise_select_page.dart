import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../exercises/exercise_definitions.dart';
import '../models/session_log.dart';
import '../storage/isar_db.dart';
import '../ui/app_scaffold_body.dart';
import '../ui/responsive.dart';
import '../utils/voice_guide.dart';
import '../widgets/task_image.dart';

class ExerciseSelectPage extends StatefulWidget {
  const ExerciseSelectPage({super.key});

  @override
  State<ExerciseSelectPage> createState() => _ExerciseSelectPageState();
}

class _ExerciseSelectPageState extends State<ExerciseSelectPage> {
  static const int _autoStartDefaultSec = 10;

  final stt.SpeechToText _pageSpeech = stt.SpeechToText();

  List<int> _recommendedIds = [];
  bool _loadingRecommendations = true;

  bool _pageSpeechReady = false;
  bool _pageListening = false;
  bool _autoActionTriggered = false;

  int _autoSecondsLeft = _autoStartDefaultSec;
  String _pageLastWords = '';

  Timer? _autoStartTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadRecommendedExercises();

      if (!mounted) return;
      setState(() {
        _loadingRecommendations = false;
      });

      await _startVoiceAndAutoFlow();
    });
  }

  @override
  void dispose() {
    _stopPageVoiceFlow();
    VoiceGuide.stop();
    super.dispose();
  }

  Map? _routeData() {
    final extra = GoRouterState.of(context).extra;
    return (extra is Map) ? extra : null;
  }

  int? _currentPatientId() {
    final data = _routeData();
    return data?['patientId'] as int?;
  }

  String _currentAffectedSide() {
    final data = _routeData();
    return (data?['affectedSide'] as String?) ?? 'L';
  }

  bool _allowRoutineStartAfterScreening() {
    final data = _routeData();
    return data?['autoStartRoutineAfterScreening'] == true;
  }

  List<int> _routeRecommendedExerciseIds() {
    final data = _routeData();
    final raw = data?['recommendedExerciseIds'];

    if (raw is List) {
      return raw
          .map((e) {
        if (e is int) return e;
        if (e is num) return e.toInt();
        return int.tryParse('$e');
      })
          .whereType<int>()
          .where((id) => id >= 0 && id <= 7)
          .toSet()
          .take(3)
          .toList();
    }

    return <int>[];
  }

  bool _shouldStartEvaluationFirst() {
    return !_allowRoutineStartAfterScreening();
  }

  void _handleBack() {
    _stopPageVoiceFlow();
    VoiceGuide.stop();

    final data = _routeData();

    final int? patientId = data?['patientId'] as int?;
    final String? affectedSide = data?['affectedSide'] as String?;

    context.go('/patient-list', extra: {
      if (patientId != null) 'patientId': patientId,
      if (affectedSide != null) 'affectedSide': affectedSide,
    });
  }

  Future<void> _loadRecommendedExercises() async {
    final routeRecommendedIds = _routeRecommendedExerciseIds();

    if (routeRecommendedIds.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _recommendedIds = routeRecommendedIds;
      });
      return;
    }

    final int? patientId = _currentPatientId();

    if (patientId == null) {
      if (!mounted) return;
      setState(() {
        _recommendedIds = [];
      });
      return;
    }

    final isar = IsarDB.instance;
    final logs = await isar.sessionLogs.where().findAll();

    final screeningLogs = logs
        .where(
          (e) =>
      e.patientId == patientId &&
          e.sessionUuid.startsWith('screening_') &&
          e.isReference == false,
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
    final latest = screeningLogs.first.sessionUuid;

    final latestLogs =
    screeningLogs.where((e) => e.sessionUuid == latest).toList();

    latestLogs.sort((a, b) => a.overall.compareTo(b.overall));

    if (!mounted) return;
    setState(() {
      _recommendedIds =
          latestLogs.map((e) => e.exerciseId).toSet().take(3).toList();
    });
  }

  void _stopPageVoiceFlow() {
    _autoStartTimer?.cancel();
    _autoStartTimer = null;

    try {
      if (_pageSpeech.isListening) {
        _pageSpeech.stop();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _pageListening = false;
      });
    }
  }

  Future<void> _startVoiceAndAutoFlow() async {
    if (!mounted) return;
    if (_loadingRecommendations) return;

    final patientId = _currentPatientId();
    if (patientId == null) return;

    _stopPageVoiceFlow();

    if (!mounted) return;
    setState(() {
      _autoActionTriggered = false;
      _autoSecondsLeft = _autoStartDefaultSec;
      _pageLastWords = '';
    });

    final hasRecommendations = _recommendedIds.isNotEmpty;
    final allowRoutineStart = _allowRoutineStartAfterScreening();
    final shouldStartEvaluation = _shouldStartEvaluationFirst();

    try {
      final available = await _pageSpeech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() {
            _pageListening = status == 'listening';
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _pageListening = false;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _pageSpeechReady = available;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pageSpeechReady = false;
        _pageListening = false;
      });
    }

    if (allowRoutineStart && hasRecommendations && !shouldStartEvaluation) {
      await VoiceGuide.speak('추천 순서대로 오늘의 운동을 시작합니다.');

      if (!mounted || _autoActionTriggered) return;

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted || _autoActionTriggered) return;

      await _triggerPrimaryAction();
      return;
    } else {
      await VoiceGuide.speak(
        '현재 상태 평가를 시작합니다. 평가라고 말하면 바로 시작합니다. '
            '말씀이 없으시면 10초 후 자동으로 시작합니다.',
      );
    }

    if (!mounted || _autoActionTriggered) return;

    _startAutoCountdown();

    if (_pageSpeechReady) {
      await _startPageListening();
    }
  }

  void _startAutoCountdown() {
    _autoStartTimer?.cancel();

    _autoStartTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_autoActionTriggered) {
        timer.cancel();
        return;
      }

      if (_autoSecondsLeft <= 1) {
        timer.cancel();
        await _triggerPrimaryAction();
        return;
      }

      setState(() {
        _autoSecondsLeft -= 1;
      });
    });
  }

  Future<void> _startPageListening() async {
    if (!_pageSpeechReady) return;
    if (_autoActionTriggered) return;

    try {
      await _pageSpeech.listen(
        onResult: (result) async {
          final words = result.recognizedWords.trim();

          if (!mounted) return;
          setState(() {
            _pageLastWords = words;
          });

          if (words.isEmpty) return;
          await _handlePageVoiceCommand(words);
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        localeId: 'ko_KR',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pageListening = false;
      });
    }
  }

  String _normalizeVoiceText(String text) {
    return text
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll('\n', '')
        .trim()
        .toLowerCase();
  }

  bool _isEvaluationCommand(String text) {
    final normalized = _normalizeVoiceText(text);

    return normalized.contains('평가') ||
        normalized.contains('상태평가') ||
        normalized.contains('현재상태') ||
        normalized.contains('검사') ||
        normalized.contains('측정');
  }

  bool _isRoutineStartCommand(String text) {
    final normalized = _normalizeVoiceText(text);

    return normalized.contains('운동시작') ||
        normalized.contains('추천운동') ||
        normalized.contains('시작') ||
        normalized.contains('운동해') ||
        normalized.contains('운동');
  }

  Future<void> _handlePageVoiceCommand(String words) async {
    if (_autoActionTriggered) return;

    final hasRecommendations = _recommendedIds.isNotEmpty;
    final allowRoutineStart = _allowRoutineStartAfterScreening();

    if (!allowRoutineStart) {
      if (_isEvaluationCommand(words)) {
        await _triggerPrimaryAction();
      }
      return;
    }

    if (allowRoutineStart &&
        hasRecommendations &&
        _isRoutineStartCommand(words)) {
      await _triggerPrimaryAction();
      return;
    }

    if (_isEvaluationCommand(words)) {
      await _triggerPrimaryAction();
      return;
    }
  }

  Future<void> _triggerPrimaryAction() async {
    if (_autoActionTriggered) return;

    setState(() {
      _autoActionTriggered = true;
    });

    _stopPageVoiceFlow();
    await VoiceGuide.stop();

    final int? patientId = _currentPatientId();
    final String affectedSide = _currentAffectedSide();

    final allowRoutineStart = _allowRoutineStartAfterScreening();

    if (allowRoutineStart && _recommendedIds.isNotEmpty) {
      _startRoutine(patientId, affectedSide);
    } else {
      await _startScreeningFlow(patientId, affectedSide);
    }
  }

  Future<void> _startScreeningFlow(
      int? patientId,
      String affectedSide,
      ) async {
    _stopPageVoiceFlow();
    await VoiceGuide.stop();

    await context.push('/screening', extra: {
      'patientId': patientId,
      'affectedSide': affectedSide,
    });

    if (!mounted) return;

    setState(() {
      _loadingRecommendations = true;
      _autoActionTriggered = false;
    });

    await _loadRecommendedExercises();

    if (!mounted) return;
    setState(() {
      _loadingRecommendations = false;
    });

    await _startVoiceAndAutoFlow();
  }

  void _startRoutine(int? patientId, String affectedSide) {
    if (patientId == null || _recommendedIds.isEmpty) return;

    _stopPageVoiceFlow();
    VoiceGuide.stop();

    final sessionUuid = DateTime.now().microsecondsSinceEpoch.toString();

    context.go('/record', extra: {
      'patientId': patientId,
      'exerciseId': _recommendedIds.first,
      'sessionUuid': sessionUuid,
      'affectedSide': affectedSide,
      'routineExerciseIds': _recommendedIds,
      'routineIndex': 0,
      'fromRoutine': true,
      'repeatCount': 1,
      'repeatIndex': 0,
      'referenceVideoPath': null,
    });
  }

  Future<void> _showRepeatCountSheet(
      dynamic ex,
      int? patientId,
      String affectedSide,
      ) async {
    _stopPageVoiceFlow();
    await VoiceGuide.stop();

    final repeatCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RepeatCountSheet(
        taskTitle: ex.taskTitle as String,
        exerciseName: ex.name as String,
        taskDescription: ex.taskDescription as String,
        taskTargetCount: ex.taskTargetCount as int,
      ),
    );

    if (repeatCount == null) {
      await _startVoiceAndAutoFlow();
      return;
    }

    final sessionUuid = DateTime.now().microsecondsSinceEpoch.toString();

    if (!mounted) return;
    context.go('/record', extra: {
      'patientId': patientId,
      'exerciseId': ex.id,
      'sessionUuid': sessionUuid,
      'affectedSide': affectedSide,
      'repeatCount': repeatCount,
      'repeatIndex': 0,
      'referenceVideoPath': null,
      'fromRoutine': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    final int? patientId = _currentPatientId();
    final String affectedSide = _currentAffectedSide();
    final items = Exercises.list;

    final isTablet = Responsive.isTablet(context);
    final sectionGap = Responsive.sectionSpacing(context);

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
          title: const Text('오늘의 상지 재활'),
        ),
        body: AppScaffoldBody(
          child: ListView(
            children: [
              _dailyFlowCard(),
              const SizedBox(height: 12),
              _voiceActionCard(),
              SizedBox(height: sectionGap),
              _sectionTitle('1. 현재 상태 평가'),
              const SizedBox(height: 8),
              _screeningCard(patientId, affectedSide),
              SizedBox(height: sectionGap),
              _sectionTitle('2. 오늘의 추천운동'),
              const SizedBox(height: 8),
              if (_loadingRecommendations)
                _infoCard('추천운동을 불러오는 중입니다...')
              else if (_recommendedIds.isEmpty ||
                  !_allowRoutineStartAfterScreening())
                _infoCard(
                  '오늘의 추천운동을 새로 만들기 위해 먼저 현재 상태 평가를 진행합니다.\n'
                      '“평가”라고 말하면 바로 시작하고, 말이 없으면 $_autoSecondsLeft초 후 자동으로 평가가 시작됩니다.',
                )
              else ...[
                  _recommendedList(items),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _startRoutine(patientId, affectedSide),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('추천운동 3개 시작하기'),
                    ),
                  ),
                ],
              SizedBox(height: sectionGap),
              _sectionTitle('치료사용 직접 선택'),
              const SizedBox(height: 8),
              Text(
                '필요 시 치료사가 직접 운동을 선택할 수 있습니다.',
                style: TextStyle(
                  fontSize: Responsive.bodyFontSize(context) - 1,
                  color: const Color(0xFF5B6676),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              if (isTablet)
                GridView.builder(
                  itemCount: items.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.65,
                  ),
                  itemBuilder: (context, index) {
                    final ex = items[index];
                    return _exerciseCard(ex, patientId, affectedSide);
                  },
                )
              else
                Column(
                  children: items.map((ex) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _exerciseCard(ex, patientId, affectedSide),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dailyFlowCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD2E2FA)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘의 진행 순서',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          _FlowStepText(
            number: '1',
            text: '현재 상태 평가하기',
          ),
          SizedBox(height: 7),
          _FlowStepText(
            number: '2',
            text: '오늘의 추천운동 3개 확인하기',
          ),
          SizedBox(height: 7),
          _FlowStepText(
            number: '3',
            text: '추천운동을 순서대로 수행하기',
          ),
        ],
      ),
    );
  }

  Widget _voiceActionCard() {
    final hasRecommendations = _recommendedIds.isNotEmpty;
    final allowRoutineStart = _allowRoutineStartAfterScreening();

    final title = allowRoutineStart && hasRecommendations
        ? '추천운동 준비 완료'
        : '현재 상태 평가 필요';

    final command = allowRoutineStart && hasRecommendations ? '운동시작' : '평가';

    final description = allowRoutineStart && hasRecommendations
        ? '추천 순서대로 첫 번째 운동을 시작합니다.'
        : '“평가”라고 말하면 현재 상태 평가를 바로 시작합니다.\n'
        '말이 없으면 $_autoSecondsLeft초 후 자동으로 평가가 시작됩니다.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic_none_rounded, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _pageListening
                      ? const Color(0xFFEAF7EE)
                      : const Color(0xFFF1F4F8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _pageListening ? '듣는 중' : '대기',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _pageListening
                        ? const Color(0xFF3FAE6F)
                        : const Color(0xFF5B6676),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _VoiceCommandPill(text: command),
              if (allowRoutineStart && hasRecommendations)
                const _VoiceCommandPill(text: '시작'),
              if (!allowRoutineStart || !hasRecommendations)
                const _VoiceCommandPill(text: '상태평가'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: Responsive.bodyFontSize(context) - 1,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF455468),
            ),
          ),
          if (_pageLastWords.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '인식된 말: $_pageLastWords',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5B6676),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Builder(
      builder: (context) => Text(
        text,
        style: TextStyle(
          fontSize: Responsive.titleFontSize(context),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoCard(String text) {
    return Builder(
      builder: (context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(Responsive.isTablet(context) ? 18 : 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FA),
          borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: Responsive.bodyFontSize(context),
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _screeningCard(int? patientId, String? affectedSide) {
    return Builder(
      builder: (context) => InkWell(
        onTap: () async {
          await _startScreeningFlow(patientId, affectedSide ?? 'L');
        },
        borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
        child: Container(
          padding: EdgeInsets.all(Responsive.isTablet(context) ? 20 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE3E8EF)),
          ),
          child: Row(
            children: [
              Container(
                width: Responsive.isTablet(context) ? 56 : 48,
                height: Responsive.isTablet(context) ? 56 : 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(
                    Responsive.isTablet(context) ? 16 : 14,
                  ),
                ),
                child: const Icon(Icons.assignment_turned_in_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '현재 상태 평가하기\n“평가”라고 말하거나 여기를 눌러 시작하세요.',
                  style: TextStyle(
                    fontSize: Responsive.bodyFontSize(context),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recommendedList(List items) {
    return Column(
      children: _recommendedIds.asMap().entries.map((entry) {
        final index = entry.key;
        final id = entry.value;
        final ex = items.firstWhere((e) => e.id == id);
        return _recommendCard(ex, index + 1);
      }).toList(),
    );
  }

  Widget _recommendCard(dynamic ex, int order) {
    return Builder(
      builder: (context) {
        final imageSize = Responsive.isTablet(context) ? 72.0 : 64.0;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.all(Responsive.isTablet(context) ? 18 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
            color: const Color(0xFFEAF2FF),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    '$order',
                    style: const TextStyle(
                      color: Color(0xFF2F67B2),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TaskImage(
                imagePath: ex.taskImagePath,
                width: imageSize,
                height: imageSize,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.taskTitle,
                      style: TextStyle(
                        fontSize: Responsive.bodyFontSize(context) + 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ex.name} 운동',
                      style: TextStyle(
                        fontSize: Responsive.bodyFontSize(context) - 2,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5B6676),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ex.taskDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Responsive.bodyFontSize(context) - 3,
                        height: 1.3,
                        color: const Color(0xFF5B6676),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _exerciseCard(dynamic ex, int? patientId, String affectedSide) {
    return Builder(
      builder: (context) {
        final isTablet = Responsive.isTablet(context);
        final imageSize = isTablet ? 92.0 : 82.0;

        return InkWell(
          onTap: () => _showRepeatCountSheet(ex, patientId, affectedSide),
          borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 18 : 16),
            decoration: BoxDecoration(
              borderRadius:
              BorderRadius.circular(Responsive.cardRadius(context)),
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE3E8EF)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TaskImage(
                  imagePath: ex.taskImagePath,
                  width: imageSize,
                  height: imageSize,
                  borderRadius: BorderRadius.circular(18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ex.taskTitle,
                        style: TextStyle(
                          fontSize: Responsive.bodyFontSize(context) + 2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ex.name} 운동',
                        style: TextStyle(
                          fontSize: Responsive.bodyFontSize(context) - 1,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5B6676),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ex.taskDescription,
                        maxLines: isTablet ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: Responsive.bodyFontSize(context) - 1,
                          height: 1.35,
                          color: const Color(0xFF5B6676),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFDCE6F2),
                          ),
                        ),
                        child: Text(
                          '목표: 1분 동안 ${ex.taskTargetCount}회 이상 성공',
                          style: TextStyle(
                            fontSize: Responsive.bodyFontSize(context) - 2,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2F67B2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '눌러서 반복 횟수를 선택하세요',
                        style: TextStyle(
                          fontSize: Responsive.bodyFontSize(context) - 2,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5B8DEF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FlowStepText extends StatelessWidget {
  final String number;
  final String text;

  const _FlowStepText({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF4F8DF7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF26313F),
            ),
          ),
        ),
      ],
    );
  }
}

class _RepeatCountSheet extends StatefulWidget {
  final String taskTitle;
  final String exerciseName;
  final String taskDescription;
  final int taskTargetCount;

  const _RepeatCountSheet({
    required this.taskTitle,
    required this.exerciseName,
    required this.taskDescription,
    required this.taskTargetCount,
  });

  @override
  State<_RepeatCountSheet> createState() => _RepeatCountSheetState();
}

class _RepeatCountSheetState extends State<_RepeatCountSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _speechReady = false;
  bool _listening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeechAndGuide();
  }

  @override
  void dispose() {
    _stopListening();
    VoiceGuide.stop();
    super.dispose();
  }

  Future<void> _initSpeechAndGuide() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() {
            _listening = status == 'listening';
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _listening = false;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _speechReady = available;
      });

      await VoiceGuide.speak(
        '반복할 횟수를 말씀해 주세요. 한번, 두번, 세번 중에서 선택할 수 있어요.',
      );

      if (_speechReady) {
        await _startListening();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _speechReady = false;
      });
    }
  }

  Future<void> _stopListening() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _listening = false;
    });
  }

  String _normalize(String text) {
    return text
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll('\n', '')
        .replaceAll('회만', '회')
        .replaceAll('번만', '번')
        .trim()
        .toLowerCase();
  }

  int? _parseRepeatCount(String text) {
    final normalized = _normalize(text);

    if (normalized.contains('한번') ||
        normalized.contains('1번') ||
        normalized.contains('일번') ||
        normalized == '1' ||
        normalized.contains('한개') ||
        normalized.contains('한회') ||
        normalized.contains('일회') ||
        normalized.contains('1회')) {
      return 1;
    }

    if (normalized.contains('두번') ||
        normalized.contains('2번') ||
        normalized.contains('이번') ||
        normalized == '2' ||
        normalized.contains('두개') ||
        normalized.contains('두회') ||
        normalized.contains('이회') ||
        normalized.contains('2회')) {
      return 2;
    }

    if (normalized.contains('세번') ||
        normalized.contains('3번') ||
        normalized.contains('삼번') ||
        normalized == '3' ||
        normalized.contains('세개') ||
        normalized.contains('세회') ||
        normalized.contains('삼회') ||
        normalized.contains('3회')) {
      return 3;
    }

    return null;
  }

  Future<void> _startListening() async {
    if (!_speechReady) return;

    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();

          if (!mounted) return;
          setState(() {
            _lastWords = words;
          });

          if (words.isEmpty) return;

          final parsed = _parseRepeatCount(words);
          if (parsed != null) {
            Navigator.of(context).pop(parsed);
          }
        },
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        localeId: 'ko_KR',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
      });
    }
  }

  Widget _countButton(int count, String voiceText) {
    return SizedBox(
      width: 96,
      height: 56,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(count),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF4F8DF7),
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count회',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              voiceText,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.maxContentWidth(context),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              margin: EdgeInsets.all(Responsive.horizontalPadding(context)),
              padding: EdgeInsets.all(isTablet ? 22 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.taskTitle,
                    style: TextStyle(
                      fontSize: Responsive.largeTitleFontSize(context) - 5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.exerciseName} 운동',
                    style: TextStyle(
                      fontSize: Responsive.bodyFontSize(context) - 1,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF5B6676),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.taskDescription,
                    style: TextStyle(
                      fontSize: Responsive.bodyFontSize(context) - 1,
                      height: 1.35,
                      color: const Color(0xFF5B6676),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAFF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFDCE6F2),
                      ),
                    ),
                    child: Text(
                      '수행 목표: 1분 동안 ${widget.taskTargetCount}회 이상 성공',
                      style: TextStyle(
                        fontSize: Responsive.bodyFontSize(context) - 2,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2F67B2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '반복할 횟수를 선택해 주세요.',
                    style: TextStyle(
                      fontSize: Responsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAFF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFDCE6F2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.mic_none_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '말로도 선택할 수 있어요',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (_speechReady)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _listening
                                      ? const Color(0xFFEAF7EE)
                                      : const Color(0xFFF1F4F8),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _listening ? '듣는 중' : '대기',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _listening
                                        ? const Color(0xFF3FAE6F)
                                        : const Color(0xFF5B6676),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _VoiceCommandPill(text: '한번'),
                            _VoiceCommandPill(text: '두번'),
                            _VoiceCommandPill(text: '세번'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _speechReady
                              ? '한번, 두번, 세번 중에서 말씀해 주세요.'
                              : '이 기기에서는 음성 인식을 사용할 수 없어요.',
                          style: TextStyle(
                            fontSize: Responsive.bodyFontSize(context) - 2,
                            height: 1.3,
                          ),
                        ),
                        if (_lastWords.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '인식된 말: $_lastWords',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5B6676),
                            ),
                          ),
                        ],
                        if (_speechReady) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _startListening,
                              icon: Icon(
                                _listening ? Icons.mic : Icons.mic_none,
                                size: 18,
                              ),
                              label: Text(
                                _listening ? '듣는 중' : '음성으로 선택하기',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _countButton(1, '한번'),
                        _countButton(2, '두번'),
                        _countButton(3, '세번'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('취소'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceCommandPill extends StatelessWidget {
  final String text;

  const _VoiceCommandPill({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 58,
        minHeight: 32,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFC9DCF8),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Color(0xFF2F67B2),
        ),
      ),
    );
  }
}