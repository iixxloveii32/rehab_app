import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../utils/voice_guide.dart';
import 'screening_plan.dart';

class ScreeningScreen extends StatefulWidget {
  const ScreeningScreen({super.key});

  @override
  State<ScreeningScreen> createState() => _ScreeningScreenState();
}

class _ScreeningScreenState extends State<ScreeningScreen> {
  static const int _autoStartDefaultSec = 10;

  final stt.SpeechToText _speech = stt.SpeechToText();

  Timer? _autoStartTimer;

  bool _speechReady = false;
  bool _listening = false;
  bool _started = false;

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
    return (extra is Map) ? extra : null;
  }

  int? _patientId() {
    final data = _routeData();
    return data?['patientId'] as int?;
  }

  String _affectedSide() {
    final data = _routeData();
    return (data?['affectedSide'] as String?) ?? 'L';
  }

  Future<void> _initVoiceAndAutoStart() async {
    final patientId = _patientId();

    if (patientId == null) {
      await VoiceGuide.speak('먼저 사용자를 선택해 주세요.');
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
      '현재 상태 평가를 시작합니다. '
          '5가지 동작을 천천히 따라해 주세요. '
          '평가라고 말하면 바로 시작합니다. '
          '말씀이 없으면 10초 후 자동으로 시작합니다.',
    );

    if (!mounted || _started) return;

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

      if (_started) {
        timer.cancel();
        return;
      }

      if (_autoSecondsLeft <= 1) {
        timer.cancel();
        await _startScreening();
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
    if (_started) return;

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
            await _startScreening();
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

    return normalized.contains('평가') ||
        normalized.contains('시작') ||
        normalized.contains('상태평가') ||
        normalized.contains('현재상태') ||
        normalized.contains('검사') ||
        normalized.contains('측정');
  }

  Future<void> _startScreening() async {
    if (_started) return;

    final patientId = _patientId();
    final affectedSide = _affectedSide();

    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 사용자를 선택해 주세요.')),
      );
      return;
    }

    setState(() {
      _started = true;
    });

    _autoStartTimer?.cancel();
    await _stopListening();
    await VoiceGuide.stop();

    final screeningSessionUuid =
        'screening_${DateTime.now().microsecondsSinceEpoch}';

    if (!mounted) return;

    context.go('/screening-camera', extra: {
      'patientId': patientId,
      'affectedSide': affectedSide,
      'screeningIndex': 0,
      'screeningTotal': screeningFunctionItems.length,
      'screeningSessionUuid': screeningSessionUuid,
      'screeningScores': <String, int>{},
      'fromAutoFlow': true,
    });
  }

  void _handleBack() {
    _autoStartTimer?.cancel();
    _stopListening();
    VoiceGuide.stop();

    final patientId = _patientId();
    final affectedSide = _affectedSide();

    context.go('/exercise', extra: {
      if (patientId != null) 'patientId': patientId,
      'affectedSide': affectedSide,
    });
  }

  @override
  Widget build(BuildContext context) {
    final patientId = _patientId();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('상지 기능 평가'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 36,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _introCard(),
                      const SizedBox(height: 12),
                      _voiceStartCard(patientId),
                      const SizedBox(height: 18),
                      const Text(
                        '평가 동작 5가지',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _screeningItemList(),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _started ? null : _startScreening,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(_started ? '평가 시작 중...' : '평가 시작하기'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _started ? null : _handleBack,
                          child: const Text('운동 선택으로 돌아가기'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _introCard() {
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
            '현재 상태 평가',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '5가지 동작을 확인한 뒤, 오늘 추천운동 3가지를 정합니다.',
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: Color(0xFF26313F),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '다음 화면에서 카메라 위치를 맞춘 뒤, 각 동작 시작 전 3초 카운트다운이 표시됩니다.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5B6676),
            ),
          ),
        ],
      ),
    );
  }

  Widget _screeningItemList() {
    return Column(
      children: List.generate(screeningFunctionItems.length, (index) {
        final item = screeningFunctionItems[index];

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3E8EF)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF2F67B2),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5B6676),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _voiceStartCard(int? patientId) {
    final canStart = patientId != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                  '평가 자동 시작',
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
                  color: _listening
                      ? const Color(0xFFEAF7EE)
                      : const Color(0xFFF1F4F8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _listening ? '듣는 중' : '대기',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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
              _ScreeningVoicePill(text: '평가'),
              _ScreeningVoicePill(text: '시작'),
              _ScreeningVoicePill(text: '상태평가'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            canStart
                ? '“평가”라고 말하면 바로 시작합니다.\n'
                '말씀이 없으면 $_autoSecondsLeft초 후 자동으로 시작합니다.'
                : '먼저 사용자를 선택해 주세요.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: Color(0xFF455468),
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
        ],
      ),
    );
  }
}

class _ScreeningVoicePill extends StatelessWidget {
  final String text;

  const _ScreeningVoicePill({
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
