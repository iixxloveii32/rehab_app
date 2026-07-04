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
        ?.map((k, v) => MapEntry('$k', _asInt(v))) ??
        <String, int>{};
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  int _totalScore(Map<String, int> scores) {
    final validScores = _orderedScoreItems(scores)
        .map((item) => item.score)
        .where((score) => score > 0)
        .toList();

    if (validScores.isEmpty) return 0;

    final total = validScores.fold<int>(0, (sum, score) => sum + score);
    return (total / validScores.length).round();
  }

  List<_ScreeningScoreItem> _orderedScoreItems(Map<String, int> scores) {
    const order = <String>[
      'flexion',
      'abduction',
      'hand_to_head',
      'hand_to_back',
      'reach_forward',
    ];

    return order
        .where((key) => scores.containsKey(key))
        .map(
          (key) => _ScreeningScoreItem(
        key: key,
        title: _labelForKey(key),
        score: scores[key] ?? 0,
      ),
    )
        .toList();
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
      '오늘의 평가 결과입니다. '
          '5가지 동작 점수와 추천운동 세 가지를 확인해 주세요. '
          '추천 순서대로 오늘의 운동을 시작합니다. '
          '말씀이 없으시면 10초 후 자동으로 운동을 시작합니다.',
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
    final recommendedIds = recommendedExerciseIdsFromScores(_scores());

    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 사용자를 선택해 주세요.')),
      );
      return;
    }

    if (recommendedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추천운동 정보가 없습니다.')),
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
      'recommendedExerciseIds': recommendedIds,
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
    final scores = _scores();
    final scoreItems = _orderedScoreItems(scores);
    final totalScore = _totalScore(scores);
    final recommendedIds = recommendedExerciseIdsFromScores(scores);

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
              Expanded(
                child: ListView(
                  children: [
                    _TotalScoreCard(totalScore: totalScore),
                    const SizedBox(height: 14),
                    _ScoreListCard(
                      items: scoreItems,
                      scoreColor: _scoreColor,
                      scoreComment: _scoreComment,
                    ),
                    const SizedBox(height: 14),
                    _RecommendedRoutineCard(
                      recommendedIds: recommendedIds,
                    ),
                    const SizedBox(height: 14),
                    _AutoStartNoticeCard(
                      listening: _listening,
                      lastWords: _lastWords,
                      secondsLeft: _autoSecondsLeft,
                      onStart: patientId == null
                          ? null
                          : () => _goExerciseAndAutoStartRoutine(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: patientId == null
                      ? null
                      : () => _goExerciseAndAutoStartRoutine(),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    _navigating ? '운동 화면으로 이동 중...' : '1번 추천운동 시작하기',
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

class _ScreeningScoreItem {
  final String key;
  final String title;
  final int score;

  const _ScreeningScoreItem({
    required this.key,
    required this.title,
    required this.score,
  });
}

class _TotalScoreCard extends StatelessWidget {
  final int totalScore;

  const _TotalScoreCard({
    required this.totalScore,
  });

  String _summaryText() {
    if (totalScore >= 80) {
      return '전반적인 상지 움직임이 좋습니다. 오늘은 움직임의 안정성과 반복 연습을 이어갑니다.';
    }
    if (totalScore >= 60) {
      return '전반적인 움직임은 확인되었습니다. 점수가 낮은 동작을 중심으로 오늘의 운동을 진행합니다.';
    }
    return '연습이 필요한 동작이 있습니다. 오늘은 우선순위가 높은 운동부터 천천히 진행합니다.';
  }

  Color _scoreColor() {
    if (totalScore >= 80) return const Color(0xFF3FAE6F);
    if (totalScore >= 60) return const Color(0xFF5B8DEF);
    return const Color(0xFFE0A63E);
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.isTablet(context) ? 24 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '상지 기능 평가 완료',
                  style: TextStyle(
                    fontSize: Responsive.largeTitleFontSize(context),
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '5가지 동작 점수를 바탕으로 오늘의 추천운동 3가지를 정했습니다.',
                  style: TextStyle(
                    fontSize: Responsive.bodyFontSize(context),
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _summaryText(),
                  style: TextStyle(
                    fontSize: Responsive.bodyFontSize(context) - 1,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF455468),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: Responsive.isTablet(context) ? 112 : 92,
            height: Responsive.isTablet(context) ? 112 : 92,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.35), width: 3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '총점',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5B6676),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalScore',
                  style: TextStyle(
                    fontSize: Responsive.isTablet(context) ? 40 : 34,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.0,
                  ),
                ),
                const Text(
                  '점',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5B6676),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreListCard extends StatelessWidget {
  final List<_ScreeningScoreItem> items;
  final Color Function(int score) scoreColor;
  final String Function(int score) scoreComment;

  const _ScoreListCard({
    required this.items,
    required this.scoreColor,
    required this.scoreComment,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            '평가 결과가 없습니다.',
            style: TextStyle(fontSize: 17),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(Responsive.isTablet(context) ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '5가지 동작 점수',
              style: TextStyle(
                fontSize: Responsive.bodyFontSize(context) + 3,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map((item) {
              final color = scoreColor(item.score);

              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: Responsive.bodyFontSize(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(minWidth: 66),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${item.score}점',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: Responsive.bodyFontSize(context) - 1,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 58,
                      child: Text(
                        scoreComment(item.score),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: Responsive.bodyFontSize(context) - 2,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RecommendedRoutineCard extends StatelessWidget {
  final List<int> recommendedIds;

  const _RecommendedRoutineCard({
    required this.recommendedIds,
  });

  @override
  Widget build(BuildContext context) {
    final exercises = recommendedIds.map((id) => Exercises.byId(id)).toList();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(Responsive.isTablet(context) ? 22 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '오늘 추천운동',
              style: TextStyle(
                fontSize: Responsive.bodyFontSize(context) + 4,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '아래 순서대로 오늘의 운동을 진행합니다.',
              style: TextStyle(
                fontSize: Responsive.bodyFontSize(context) - 1,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5B6676),
              ),
            ),
            const SizedBox(height: 14),
            if (exercises.isEmpty)
              const Text(
                '추천운동 정보가 없습니다.',
                style: TextStyle(fontSize: 16),
              )
            else
              ...List.generate(exercises.length, (index) {
                final ex = exercises[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RecommendedStepTile(
                    index: index,
                    taskTitle: ex.taskTitle,
                    exerciseName: ex.name,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RecommendedStepTile extends StatelessWidget {
  final int index;
  final String taskTitle;
  final String exerciseName;

  const _RecommendedStepTile({
    required this.index,
    required this.taskTitle,
    required this.exerciseName,
  });

  @override
  Widget build(BuildContext context) {
    final number = index + 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC9DCF8)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2F67B2),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taskTitle,
                  style: TextStyle(
                    fontSize: Responsive.bodyFontSize(context) + 1,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1F2A37),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$exerciseName 운동',
                  style: TextStyle(
                    fontSize: Responsive.bodyFontSize(context) - 1,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF455468),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoStartNoticeCard extends StatelessWidget {
  final bool listening;
  final String lastWords;
  final int secondsLeft;
  final VoidCallback? onStart;

  const _AutoStartNoticeCard({
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
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6F2)),
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
                  '운동 시작 안내',
                  style: TextStyle(
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
          Text(
            '“운동시작”이라고 말하면 바로 시작합니다.\n'
                '말씀이 없으시면 $secondsLeft초 후 1번 추천운동이 자동으로 시작됩니다.',
            style: TextStyle(
              fontSize: Responsive.bodyFontSize(context) - 1,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF455468),
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
              label: const Text('바로 운동 시작'),
            ),
          ),
        ],
      ),
    );
  }
}
