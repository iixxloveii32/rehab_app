import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../exercises/exercise_definitions.dart';
import '../ui/app_scaffold_body.dart';
import '../ui/responsive.dart';
import '../utils/voice_guide.dart';
import 'screening_plan.dart';

class ScreeningResultPage extends StatefulWidget {
  const ScreeningResultPage({super.key});

  @override
  State<ScreeningResultPage> createState() => _ScreeningResultPageState();
}

class _ScreeningResultPageState extends State<ScreeningResultPage> {
  static const int _autoStartDefaultSec = 10;

  final stt.SpeechToText _speech = stt.SpeechToText();

  Timer? _autoStartTimer;

  bool _speechReady = false;
  bool _listening = false;
  bool _navigating = false;

  int _autoSecondsLeft = _autoStartDefaultSec;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initVoiceAndAutoStart();
    });
  }

  @override
  void dispose() {
    _autoStartTimer?.cancel();
    _stopListening();
    VoiceGuide.stop();
    super.dispose();
  }

  Map? _routeData() {
    final extra = GoRouterState.of(context).extra;
    return extra is Map ? extra : null;
  }

  int? _patientId() {
    final data = _routeData();
    return data?['patientId'] as int?;
  }

  String _affectedSide() {
    final data = _routeData();
    return (data?['affectedSide'] as String?) ?? 'L';
  }

  Map<String, int> _scores() {
    final data = _routeData();

    return (data?['screeningScores'] as Map?)
        ?.map((k, v) => MapEntry('$k', v as int)) ??
        <String, int>{};
  }

  Future<void> _initVoiceAndAutoStart() async {
    final patientId = _patientId();

    if (patientId == null) {
      await VoiceGuide.speak('사용자 정보가 없어 오늘의 운동을 시작할 수 없습니다.');
      return;
    }

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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _speechReady = false;
        _listening = false;
      });
    }

    await VoiceGuide.speak(
      '평가가 완료되었습니다. '
          '오늘의 추천운동을 시작하려면 운동시작이라고 말해 주세요. '
          '말이 없으면 10초 후 자동으로 오늘의 운동 화면으로 이동합니다.',
    );

    if (!mounted || _navigating) return;

    _startAutoCountdown();

    if (_speechReady) {
      await _startListening();
    }
  }

  void _startAutoCountdown() {
    _autoStartTimer?.cancel();

    setState(() {
      _autoSecondsLeft = _autoStartDefaultSec;
    });

    _autoStartTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_navigating) {
        timer.cancel();
        return;
      }

      if (_autoSecondsLeft <= 1) {
        timer.cancel();
        await _goExerciseAndAutoStartRoutine();
        return;
      }

      setState(() {
        _autoSecondsLeft -= 1;
      });
    });
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

  Future<void> _startListening() async {
    if (!_speechReady) return;
    if (_navigating) return;

    try {
      await _speech.listen(
        onResult: (result) async {
          final words = result.recognizedWords.trim();

          if (!mounted) return;
          setState(() {
            _lastWords = words;
          });

          if (words.isEmpty) return;

          if (_isStartCommand(words)) {
            await _goExerciseAndAutoStartRoutine();
          }
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
        _listening = false;
      });
    }
  }

  String _normalize(String text) {
    return text
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll('\n', '')
        .trim()
        .toLowerCase();
  }

  bool _isStartCommand(String text) {
    final normalized = _normalize(text);

    return normalized.contains('운동시작') ||
        normalized.contains('오늘의운동') ||
        normalized.contains('추천운동') ||
        normalized.contains('시작') ||
        normalized.contains('운동') ||
        normalized.contains('다음');
  }

  Future<void> _goExerciseAndAutoStartRoutine() async {
    if (_navigating) return;

    final patientId = _patientId();
    final affectedSide = _affectedSide();

    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 사용자를 선택해 주세요.')),
      );
      return;
    }

    setState(() {
      _navigating = true;
    });

    _autoStartTimer?.cancel();
    await _stopListening();
    await VoiceGuide.stop();

    if (!mounted) return;

    context.go('/exercise', extra: {
      'patientId': patientId,
      'affectedSide': affectedSide,
      'fromScreening': true,
      'autoStartRoutineAfterScreening': true,
    });
  }

  void _goExerciseOnly() {
    final patientId = _patientId();
    final affectedSide = _affectedSide();

    _autoStartTimer?.cancel();
    _stopListening();
    VoiceGuide.stop();

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
    final int? patientId = _patientId();
    final String affectedSide = _affectedSide();

    final Map<String, int> scores = _scores();

    final recommendedIds = recommendedExerciseIdsFromScores(scores);
    final summary = screeningSummaryText(scores);

    final sortedScores = scores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final isTablet = Responsive.isTablet(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goExerciseOnly();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goExerciseOnly,
          ),
          title: const Text('상지 기능 평가 결과'),
        ),
        body: AppScaffoldBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScreeningSummaryCard(summary: summary),
              const SizedBox(height: 12),
              _AutoStartExerciseCard(
                listening: _listening,
                lastWords: _lastWords,
                secondsLeft: _autoSecondsLeft,
                onStart: patientId == null ? null : _goExerciseAndAutoStartRoutine,
              ),
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
                            width:
                            (Responsive.maxContentWidth(context) -
                                12) /
                                2,
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
                  onPressed:
                  patientId == null ? null : _goExerciseAndAutoStartRoutine,
                  child: Text(
                    _navigating ? '운동 화면으로 이동 중...' : '오늘의 운동 시작하기',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: patientId == null ? null : _goExerciseOnly,
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

class _AutoStartExerciseCard extends StatelessWidget {
  final bool listening;
  final String lastWords;
  final int secondsLeft;
  final VoidCallback? onStart;

  const _AutoStartExerciseCard({
    required this.listening,
    required this.lastWords,
    required this.secondsLeft,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic_none_rounded, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '오늘의 운동 자동 시작',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: listening
                      ? const Color(0xFFEAF7EE)
                      : const Color(0xFFF1F4F8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  listening ? '듣는 중' : '대기',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: listening
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
              _ResultVoicePill(text: '운동시작'),
              _ResultVoicePill(text: '시작'),
              _ResultVoicePill(text: '추천운동'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '“운동시작”이라고 말하면 오늘의 추천운동을 바로 시작합니다.\n'
                '말이 없으면 $secondsLeft초 후 자동으로 운동 화면으로 이동합니다.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: Color(0xFF455468),
            ),
          ),
          if (lastWords.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '인식된 말: $lastWords',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5B6676),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('바로 시작하기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultVoicePill extends StatelessWidget {
  final String text;

  const _ResultVoicePill({
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
    final exercises = recommendedIds.map((id) => Exercises.byId(id)).toList();

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
            ...List.generate(exercises.length, (index) {
              final ex = exercises[index];

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
                    '${index + 1}. ${ex.taskTitle}\n   ${ex.name} 운동',
                    style: TextStyle(
                      fontSize: Responsive.bodyFontSize(context) + 1,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Text(
              '“운동시작”이라고 말하거나 아래 버튼을 누르면 오늘의 추천운동을 시작할 수 있어요.',
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