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
          '시작 또는 평가라고 말하면 바로 시작합니다. '
          '말이 없으면 10초 후 자동으로 평가가 시작됩니다.',
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

    return normalized.contains('시작') ||
        normalized.contains('평가') ||
        normalized.contains('평가시작') ||
        normalized.contains('상태평가') ||
        normalized.contains('현재상태') ||
        normalized.contains('검사') ||
        normalized.contains('준비');
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '상지 기능 평가',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '간단한 5가지 동작을 통해 현재 상지 기능을 확인합니다.\n'
                            '화면 안내에 따라 천천히 움직여 주세요.\n'
                            '각 동작은 예시와 안내 문구가 함께 제공됩니다.',
                        style: TextStyle(fontSize: 15, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _voiceStartCard(patientId),
                const SizedBox(height: 20),
                const Text(
                  '평가 동작',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: screeningFunctionItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = screeningFunctionItems[index];
                      return ListTile(
                        tileColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(item.title),
                        subtitle: Text(item.desc),
                        trailing: const Icon(Icons.chevron_right),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _started ? null : _startScreening,
                    child: Text(_started ? '평가 시작 중...' : '평가 시작하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _voiceStartCard(int? patientId) {
    final canStart = patientId != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  '자동 평가 시작',
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _ScreeningVoicePill(text: '시작'),
              _ScreeningVoicePill(text: '평가'),
              _ScreeningVoicePill(text: '평가시작'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            canStart
                ? '“시작” 또는 “평가”라고 말하면 바로 평가를 시작합니다.\n'
                '말이 없으면 $_autoSecondsLeft초 후 자동으로 평가가 시작됩니다.'
                : '먼저 사용자를 선택해 주세요.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
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