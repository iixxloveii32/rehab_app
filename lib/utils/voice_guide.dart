import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

class VoiceGuide {
  VoiceGuide._();

  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;
  static Timer? _delayedSpeakTimer;

  static Future<void> init() async {
    if (_initialized) return;

    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);

    _initialized = true;
  }

  static Future<void> speak(String text) async {
    await init();
    await _tts.stop();
    await _tts.speak(text);
  }

  static Future<void> speakDelayed(
      String text, {
        Duration delay = const Duration(milliseconds: 300),
      }) async {
    _delayedSpeakTimer?.cancel();
    _delayedSpeakTimer = Timer(delay, () {
      speak(text);
    });
  }

  static Future<void> stop() async {
    _delayedSpeakTimer?.cancel();
    await _tts.stop();
  }

  static void disposeTimer() {
    _delayedSpeakTimer?.cancel();
  }
}