import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../config/app_config.dart';
import '../exercises/exercise_definitions.dart';
import '../models/session_log.dart';
import '../storage/isar_db.dart';
import '../utils/voice_guide.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  bool _saving = true;
  String? _error;

  int? _patientId;
  int _exerciseId = 0;

  List<int> _routineExerciseIds = [];
  int _routineIndex = 0;
  bool _fromRoutine = false;

  int _repeatCount = 1;
  int _repeatIndex = 0;
  String? _referenceVideoPath;

  int _overall = 0;
  int _symmetry = 0;
  int _timing = 0;
  int _smoothness = 0;
  int _compensation = 0;
  int _rom = 0;

  int _taskTargetCount = 5;
  int _taskSuccessCount = 0;
  double _taskSuccessRate = 0.0;
  double _taskScore = 0.0;
  double _finalTaskOrientedScore = 0.0;

  late String _affectedSide;

  String? _sessionUuid;
  int _attemptIndex = 0;

  Map<String, dynamic> _quality = <String, dynamic>{};
  Map<String, dynamic> _features = <String, dynamic>{};

  Timer? _autoTimer;
  int _secondsLeft = 5;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  String _lastRecognizedWords = '';

  bool get _hasRoutine => _fromRoutine && _routineExerciseIds.isNotEmpty;
  bool get _isLastRoutineItem {
    if (!_hasRoutine) return false;
    return _routineIndex >= _routineExerciseIds.length - 1;
  }

  bool get _isRepeatMode => _repeatCount > 1;
  bool get _isLastRepeat => _repeatIndex >= _repeatCount - 1;
  bool get _hasMoreRepeats => _repeatIndex < _repeatCount - 1;
  int get _currentRepeatNumber => _repeatIndex + 1;
  int get _nextRepeatNumber => _repeatIndex + 2;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveScore());
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _stopListening();
    VoiceGuide.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
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

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _retakeMessage() {
    final reason = _quality['reason']?.toString();

    switch (reason) {
      case 'wrong_reference_side_performed':
        return '기준 촬영에서 반대쪽 팔이 더 많이 움직였어요.\n건강한 쪽 팔로 다시 촬영해 주세요.';
      case 'wrong_side_performed':
        return '따라하기에서 반대쪽 팔이 더 많이 움직였어요.\n환측 팔로 다시 해 주세요.';
      case 'low_visibility_or_too_few_frames':
        return '몸과 팔이 화면 안에 잘 보이게 다시 촬영해 주세요.\n조금 더 멀리 서면 더 잘 인식돼요.';
      default:
        if (reason != null && reason.startsWith('no_meaningful_')) {
          return '움직임이 작게 인식되었어요.\n팔을 조금 더 크게 움직여 다시 해 보세요.';
        }
        return '움직임이 작거나 화면 인식이 어려웠어요.\n다시 한 번 천천히 촬영해 보세요.';
    }
  }

  String _scoreTitle() {
    if (_quality['needsRetake'] == true) {
      return '다시 한 번 해볼게요';
    }
    if (_hasMoreRepeats) {
      return '좋아요. 한 번 더 해볼게요';
    }
    if (_overall >= 85) return '아주 좋아요';
    if (_overall >= 70) return '잘했어요';
    if (_overall >= 50) return '조금 더 연습해볼게요';
    return '다시 해보면 더 좋아질 수 있어요';
  }

  String _scoreComment() {
    if (_quality['needsRetake'] == true) {
      return _retakeMessage();
    }
    if (_hasMoreRepeats) {
      if (_overall >= 85) {
        return '이번 반복은 아주 좋았어요. 같은 동작을 한 번 더 해볼게요.';
      }
      if (_overall >= 70) {
        return '좋아요. 이번엔 조금 더 안정적으로 해볼게요.';
      }
      if (_overall >= 50) {
        return '동작은 잘 보였어요. 다음 반복에서 조금 더 크게 해보세요.';
      }
      return '다음 반복에서는 조금 더 천천히, 크게 움직여 보세요.';
    }
    if (_overall >= 85) {
      return '동작이 안정적으로 잘 수행되었어요.';
    }
    if (_overall >= 70) {
      return '전반적으로 잘 수행했어요. 조금만 더 다듬으면 더 좋아요.';
    }
    if (_overall >= 50) {
      return '목표 동작은 보였지만 범위나 안정성이 더 필요해요.';
    }
    return '조금 더 크게, 천천히 다시 해보면 더 정확하게 평가할 수 있어요.';
  }

  String _repeatCoachingMessage() {
    final scoreMap = <String, int>{
      'rom': _rom,
      'compensation': _compensation,
      'symmetry': _symmetry,
      'smoothness': _smoothness,
      'timing': _timing,
    };

    String lowestKey = 'rom';
    int lowestValue = 999;

    scoreMap.forEach((key, value) {
      if (value < lowestValue) {
        lowestValue = value;
        lowestKey = key;
      }
    });

    switch (lowestKey) {
      case 'rom':
        return '이번에는 팔을 조금 더 크게 움직여 보세요.';
      case 'compensation':
        return '몸통이 기울지 않도록 천천히 다시 해보세요.';
      case 'symmetry':
        return '좌우 균형을 맞춘다는 느낌으로 해보세요.';
      case 'smoothness':
        return '조금 더 부드럽게 이어서 움직여 보세요.';
      case 'timing':
        return '예시 영상을 보며 속도를 조금 더 맞춰보세요.';
      default:
        return '이번에는 조금 더 천천히 정확하게 해보세요.';
    }
  }

  String _labelForScore(String key) {
    switch (key) {
      case 'rom':
        return '동작 범위';
      case 'compensation':
        return '몸통 안정성';
      case 'symmetry':
        return '좌우 균형';
      case 'smoothness':
        return '움직임 부드러움';
      case 'timing':
        return '속도 맞추기';
      default:
        return key;
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

  int _recommendedExerciseId() {
    final scoreMap = <String, int>{
      'rom': _rom,
      'compensation': _compensation,
      'symmetry': _symmetry,
      'smoothness': _smoothness,
      'timing': _timing,
    };

    String lowestKey = 'rom';
    int lowestValue = 999;

    scoreMap.forEach((key, value) {
      if (value < lowestValue) {
        lowestValue = value;
        lowestKey = key;
      }
    });

    switch (lowestKey) {
      case 'rom':
        return _exerciseId;
      case 'compensation':
        return 0;
      case 'symmetry':
        return 1;
      case 'smoothness':
        return 6;
      case 'timing':
        return 4;
      default:
        return _exerciseId;
    }
  }

  String _recommendedReason() {
    final scoreMap = <String, int>{
      'rom': _rom,
      'compensation': _compensation,
      'symmetry': _symmetry,
      'smoothness': _smoothness,
      'timing': _timing,
    };

    String lowestKey = 'rom';
    int lowestValue = 999;

    scoreMap.forEach((key, value) {
      if (value < lowestValue) {
        lowestValue = value;
        lowestKey = key;
      }
    });

    switch (lowestKey) {
      case 'rom':
        return '${_exerciseName(_exerciseId)} 기능이 더 필요해 같은 동작을 한 번 더 추천해요.';
      case 'compensation':
        return '몸통 보상을 줄이며 안정적으로 움직이기 위해 팔 앞으로 들기를 추천해요.';
      case 'symmetry':
        return '좌우 균형 향상을 위해 팔 옆으로 들기를 추천해요.';
      case 'smoothness':
        return '움직임을 더 부드럽게 하기 위해 팔 굽히기를 추천해요.';
      case 'timing':
        return '목표 지점을 향한 타이밍 연습을 위해 앞으로 손 뻗기를 추천해요.';
      default:
        return '현재 상태를 바탕으로 다음 운동을 추천해요.';
    }
  }

  int? _nextRoutineExerciseId() {
    if (!_hasRoutine || _isLastRoutineItem) return null;
    return _routineExerciseIds[_routineIndex + 1];
  }

  String _normalizeSpeech(String text) {
    return text
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll('\n', '')
        .trim()
        .toLowerCase();
  }

  String _voiceGuideText(bool needsRetake) {
    if (needsRetake) {
      return '원하시면 말로도 선택할 수 있어요. 다시 라고 말하면 다시 시작합니다.';
    }

    if (_hasMoreRepeats) {
      return '원하시면 말로도 선택할 수 있어요. 다음 이라고 말하면 다음 반복을 시작합니다.';
    }

    if (_hasRoutine) {
      if (_isLastRoutineItem) {
        return '원하시면 말로도 선택할 수 있어요. 결과 또는 종료 라고 말하면 결과 화면으로 이동합니다.';
      }
      return '원하시면 말로도 선택할 수 있어요. 다음 이라고 말하면 다음 운동을 시작합니다. 종료 라고 말하면 오늘 운동을 마칩니다.';
    }

    return '원하시면 말로도 선택할 수 있어요. 다음 이라고 말하면 다음 추천 운동을 시작합니다. 선택 이라고 말하면 운동 선택 화면으로 이동합니다. 종료 라고 말하면 오늘 운동을 종료합니다.';
  }

  List<String> _voiceCommands(bool needsRetake) {
    if (needsRetake) {
      return const ['다시'];
    }

    if (_hasMoreRepeats) {
      return const ['다음'];
    }

    if (_hasRoutine) {
      if (_isLastRoutineItem) {
        return const ['결과', '종료'];
      }
      return const ['다음', '종료'];
    }

    return const ['다음', '선택', '종료'];
  }

  Future<void> _announceVoiceCommandsAndListen(bool needsRetake) async {
    if (!_speechReady) return;

    await _stopListening();
    await VoiceGuide.speak(_voiceGuideText(needsRetake));
    await _startListening(needsRetake: needsRetake);
  }

  Future<void> _startListening({required bool needsRetake}) async {
    if (!_speechReady) return;

    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();

          if (!mounted) return;
          setState(() {
            _lastRecognizedWords = words;
          });

          if (words.isEmpty) return;

          final normalized = _normalizeSpeech(words);

          if (needsRetake) {
            if (normalized.contains('다시') ||
                normalized.contains('재시도') ||
                normalized.contains('다시시작')) {
              _retryCurrentExercise();
              return;
            }
            return;
          }

          if (_hasMoreRepeats) {
            if (normalized.contains('다음') || normalized.contains('시작')) {
              _goNextRepeat();
              return;
            }
            return;
          }

          if (_hasRoutine) {
            if (_isLastRoutineItem) {
              if (normalized.contains('결과') ||
                  normalized.contains('완료') ||
                  normalized.contains('종료')) {
                _goNextRoutineStep();
                return;
              }
            } else {
              if (normalized.contains('다음') || normalized.contains('시작')) {
                _goNextRoutineStep();
                return;
              }
              if (normalized.contains('종료') ||
                  normalized.contains('여기까지')) {
                _autoTimer?.cancel();
                context.go('/results', extra: {
                  'patientId': _patientId,
                  'sessionUuid': _sessionUuid,
                  'affectedSide': _affectedSide,
                });
                return;
              }
            }
          } else {
            if (normalized.contains('다음') || normalized.contains('시작')) {
              _goRecommendedExercise();
              return;
            }
            if (normalized.contains('선택') ||
                normalized.contains('직접선택')) {
              _autoTimer?.cancel();
              context.go('/exercise', extra: {
                'patientId': _patientId,
                'affectedSide': _affectedSide,
              });
              return;
            }
            if (normalized.contains('종료') ||
                normalized.contains('결과') ||
                normalized.contains('여기까지')) {
              _autoTimer?.cancel();
              context.go('/results', extra: {
                'patientId': _patientId,
                'sessionUuid': _sessionUuid,
                'affectedSide': _affectedSide,
              });
              return;
            }
          }
        },
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
      });
    }
  }

  void _startAutoNext() {
    _autoTimer?.cancel();
    _secondsLeft = 5;

    _autoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsLeft <= 1) {
        timer.cancel();

        if (_hasMoreRepeats) {
          _goNextRepeat();
          return;
        }

        if (_hasRoutine) {
          _goNextRoutineStep();
        } else {
          _goRecommendedExercise();
        }
      } else {
        setState(() {
          _secondsLeft -= 1;
        });
      }
    });
  }

  void _goRecommendedExercise() {
    _autoTimer?.cancel();
    _stopListening();

    context.go('/record', extra: {
      'patientId': _patientId,
      'exerciseId': _recommendedExerciseId(),
      'sessionUuid': DateTime.now().microsecondsSinceEpoch.toString(),
      'affectedSide': _affectedSide,
      'repeatCount': 1,
      'repeatIndex': 0,
      'referenceVideoPath': null,
    });
  }

  void _goNextRoutineStep() {
    _autoTimer?.cancel();
    _stopListening();

    if (_isLastRoutineItem) {
      context.go('/results', extra: {
        'patientId': _patientId,
        'sessionUuid': _sessionUuid,
        'affectedSide': _affectedSide,
      });
      return;
    }

    final nextExerciseId = _nextRoutineExerciseId();
    if (nextExerciseId == null) {
      context.go('/results', extra: {
        'patientId': _patientId,
        'sessionUuid': _sessionUuid,
        'affectedSide': _affectedSide,
      });
      return;
    }

    context.go('/record', extra: {
      'patientId': _patientId,
      'exerciseId': nextExerciseId,
      'sessionUuid': _sessionUuid,
      'affectedSide': _affectedSide,
      'routineExerciseIds': _routineExerciseIds,
      'routineIndex': _routineIndex + 1,
      'fromRoutine': true,
      'repeatCount': 1,
      'repeatIndex': 0,
      'referenceVideoPath': null,
    });
  }

  void _goNextRepeat() {
    _autoTimer?.cancel();
    _stopListening();

    final refPath = _referenceVideoPath;
    if (refPath == null || refPath.isEmpty || !File(refPath).existsSync()) {
      _retryCurrentExercise();
      return;
    }

    context.go('/review', extra: {
      'videoPath': refPath,
      'referenceVideoPath': refPath,
      'patientId': _patientId,
      'exerciseId': _exerciseId,
      'sessionUuid': _sessionUuid,
      'affectedSide': _affectedSide,
      'routineExerciseIds': _routineExerciseIds,
      'routineIndex': _routineIndex,
      'fromRoutine': _fromRoutine,
      'repeatCount': _repeatCount,
      'repeatIndex': _repeatIndex + 1,
    });
  }

  void _retryCurrentExercise() {
    _autoTimer?.cancel();
    _stopListening();

    final refPath = _referenceVideoPath;
    if (_isRepeatMode &&
        refPath != null &&
        refPath.isNotEmpty &&
        File(refPath).existsSync()) {
      context.go('/review', extra: {
        'videoPath': refPath,
        'referenceVideoPath': refPath,
        'patientId': _patientId,
        'exerciseId': _exerciseId,
        'sessionUuid': _sessionUuid,
        'affectedSide': _affectedSide,
        'routineExerciseIds': _routineExerciseIds,
        'routineIndex': _routineIndex,
        'fromRoutine': _fromRoutine,
        'repeatCount': _repeatCount,
        'repeatIndex': _repeatIndex,
      });
      return;
    }

    context.go('/record', extra: {
      'patientId': _patientId,
      'exerciseId': _exerciseId,
      'sessionUuid': _sessionUuid,
      'affectedSide': _affectedSide,
      'routineExerciseIds': _routineExerciseIds,
      'routineIndex': _routineIndex,
      'fromRoutine': _fromRoutine,
      'repeatCount': _repeatCount,
      'repeatIndex': 0,
      'referenceVideoPath': null,
    });
  }

  Future<void> _saveScore() async {
    try {
      final extra = GoRouterState.of(context).extra;
      final data = (extra is Map) ? extra : null;

      _affectedSide = (data?['affectedSide'] as String?) ?? 'L';

      _fromRoutine = (data?['fromRoutine'] as bool?) ?? false;
      final rawRoutineIds = data?['routineExerciseIds'];
      if (rawRoutineIds is List) {
        _routineExerciseIds = rawRoutineIds.map((e) => e as int).toList();
      } else {
        _routineExerciseIds = [];
      }
      _routineIndex = (data?['routineIndex'] as int?) ?? 0;

      _repeatCount = (data?['repeatCount'] as int?) ?? 1;
      _repeatIndex = (data?['repeatIndex'] as int?) ?? 0;

      final patientId = data?['patientId'] as int?;
      final modelPath = data?['modelPath'] as String?;
      final patientPath = data?['patientPath'] as String?;
      final exerciseId = (data?['exerciseId'] as int?) ?? 0;
      final incomingSessionUuid = data?['sessionUuid'] as String?;

      if (patientId == null) throw Exception('patientId가 없습니다.');
      if (modelPath == null || modelPath.isEmpty) {
        throw Exception('modelPath가 없습니다.');
      }
      if (patientPath == null || patientPath.isEmpty) {
        throw Exception('patientPath가 없습니다.');
      }

      _referenceVideoPath = modelPath;
      _patientId = patientId;
      _exerciseId = exerciseId;

      final now = DateTime.now();
      final todayKey = _dateKey(now);
      final sessionUuid =
          incomingSessionUuid ?? DateTime.now().microsecondsSinceEpoch.toString();
      _sessionUuid = sessionUuid;

      final isar = IsarDB.instance;
      final allLogs = await isar.sessionLogs.where().findAll();

      final existingImitLogs = allLogs
          .where((log) =>
      log.patientId == patientId &&
          log.exerciseId == exerciseId &&
          log.dateKey == todayKey &&
          log.isReference == false)
          .toList();

      _attemptIndex = existingImitLogs.length + 1;

      final result = await _analyzeViaServer(
        referenceVideoPath: modelPath,
        imitationVideoPath: patientPath,
      );

      _symmetry = result.symmetry;
      _timing = result.timing;
      _smoothness = result.smoothness;
      _compensation = result.compensation;
      _rom = result.rom;
      _overall = result.overall;

      _taskTargetCount = result.taskTargetCount;
      _taskSuccessCount = result.taskSuccessCount;
      _taskSuccessRate = result.taskSuccessRate;
      _taskScore = result.taskScore;
      _finalTaskOrientedScore = result.finalTaskOrientedScore;

      _quality = result.quality;
      _features = result.features;

      final existingRefs = allLogs
          .where((log) => log.sessionUuid == sessionUuid && log.isReference)
          .toList();

      final refExists = existingRefs.isNotEmpty;

      final refLog = SessionLog()
        ..patientId = patientId
        ..exerciseId = exerciseId
        ..timestampKst = now
        ..dateKey = todayKey
        ..sessionUuid = sessionUuid
        ..isReference = true
        ..attemptIndex = 0
        ..overall = 0
        ..symmetry = 0
        ..timing = 0
        ..smoothness = 0
        ..compensation = 0
        ..rom = 0
        ..referenceVideoPath = modelPath
        ..imitationVideoPath = null
        ..qualityJson = jsonEncode(result.quality)
        ..featuresJson = null;

      final imitLog = SessionLog()
        ..patientId = patientId
        ..exerciseId = exerciseId
        ..timestampKst = now
        ..dateKey = todayKey
        ..sessionUuid = sessionUuid
        ..isReference = false
        ..attemptIndex = _attemptIndex
        ..overall = result.overall
        ..symmetry = result.symmetry
        ..timing = result.timing
        ..smoothness = result.smoothness
        ..compensation = result.compensation
        ..rom = result.rom
        ..referenceVideoPath = modelPath
        ..imitationVideoPath = patientPath
        ..qualityJson = jsonEncode(result.quality)
        ..featuresJson = jsonEncode(result.features);

      await isar.writeTxn(() async {
        if (!refExists) {
          await isar.sessionLogs.put(refLog);
        }
        await isar.sessionLogs.put(imitLog);
      });

      if (!mounted) return;
      setState(() => _saving = false);

      final needsRetake = result.quality['needsRetake'] == true;

      if (needsRetake) {
        await VoiceGuide.speak('다시 한 번 촬영해 주세요.');
        await _announceVoiceCommandsAndListen(true);
        return;
      }

      if (_hasMoreRepeats) {
        await VoiceGuide.speak(
          '잘하셨습니다. ${_nextRepeatNumber}번째 반복으로 넘어갑니다.',
        );

        await _announceVoiceCommandsAndListen(false);
        return;
      }

      if (_hasRoutine) {
        if (_isLastRoutineItem) {
          await VoiceGuide.speak('잘하셨습니다. 오늘의 운동이 완료되었습니다.');
        } else {
          await VoiceGuide.speak('잘하셨습니다. 다음 운동으로 넘어갑니다.');
        }
        _startAutoNext();
        await _announceVoiceCommandsAndListen(false);
      } else {
        await VoiceGuide.speak('잘하셨습니다. 다음 추천 운동으로 넘어갑니다.');
        _startAutoNext();
        await _announceVoiceCommandsAndListen(false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  Future<_MockResult> _analyzeViaServer({
    required String referenceVideoPath,
    required String imitationVideoPath,
  }) async {
    final uri = Uri.parse(AppConfig.analyzeEndpoint);

    final exercise = Exercises.byId(_exerciseId);

    final req = http.MultipartRequest('POST', uri)
      ..files.add(
        await http.MultipartFile.fromPath('reference', referenceVideoPath),
      )
      ..files.add(
        await http.MultipartFile.fromPath('imitation', imitationVideoPath),
      )
      ..fields['exerciseId'] = _exerciseId.toString()
      ..fields['affectedSide'] = _affectedSide
      ..fields['taskTargetCount'] = exercise.taskTargetCount.toString()
      ..fields['taskStandardVersion'] = AppConfig.taskStandardVersion
      ..fields['scoreSchemaVersion'] = AppConfig.scoreSchemaVersion.toString()
      ..fields['appVersion'] = AppConfig.appVersion;


    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      throw Exception('분석 서버 오류 ${resp.statusCode}: ${resp.body}');
    }

    final j = jsonDecode(resp.body) as Map<String, dynamic>;

    final features =
        (j['features'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final quality =
        (j['quality'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    int asInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is num) return v.round();
      return int.tryParse(v.toString()) ?? fallback;
    }

    double asDouble(dynamic v, {double fallback = 0.0}) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    final fallbackTargetCount = exercise.taskTargetCount;

    return _MockResult(
      overall: asInt(j['overall']),
      symmetry: asInt(j['symmetry']),
      timing: asInt(j['timing']),
      smoothness: asInt(j['smoothness']),
      compensation: asInt(j['compensation']),
      rom: asInt(j['rom']),
      taskTargetCount: asInt(
        j['taskTargetCount'],
        fallback: fallbackTargetCount,
      ),
      taskSuccessCount: asInt(j['taskSuccessCount']),
      taskSuccessRate: asDouble(j['taskSuccessRate']),
      taskScore: asDouble(j['taskScore']),
      finalTaskOrientedScore: asDouble(j['finalTaskOrientedScore']),
      quality: quality,
      features: features,
    );
  }

  Color _scoreColor(int value) {
    if (value >= 85) return const Color(0xFF3FAE6F);
    if (value >= 70) return const Color(0xFF5B8DEF);
    if (value >= 50) return const Color(0xFFE0A63E);
    return const Color(0xFFE57373);
  }

  Widget _scoreTile(String label, int value) {
    final color = _scoreColor(value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$value점',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultSummaryCard(bool needsRetake) {
    final color = needsRetake
        ? const Color(0xFFFFF3E8)
        : const Color(0xFFEAF2FF);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _scoreTitle(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '총점',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$_overall',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  '점',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _scoreComment(),
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskResultCard() {
    final percent = (_taskSuccessRate * 100).clamp(0, 999).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '과제 수행 결과',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _taskMetricBox(
                  label: '목표',
                  value: '${_taskTargetCount}회 이상',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _taskMetricBox(
                  label: '성공',
                  value: '${_taskSuccessCount}회',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _taskMetricBox(
                  label: '달성률',
                  value: '$percent%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _taskScoreRow(
            label: '과제 성공 점수',
            value: _taskScore,
          ),
          const SizedBox(height: 8),
          _taskScoreRow(
            label: '최종 과제지향 점수',
            value: _finalTaskOrientedScore,
          ),
          const SizedBox(height: 10),
          const Text(
            '성공 횟수는 실제 수행 횟수로 저장하고, 과제 성공 점수는 100점까지 반영합니다.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF5B6676),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskMetricBox({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E8EF)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5B6676),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2F67B2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskScoreRow({
    required String label,
    required double value,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '${value.round()}점',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2F67B2),
          ),
        ),
      ],
    );
  }

  Widget _repeatSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '좋아요. 한 번 더 해볼게요',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '현재 반복',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$_currentRepeatNumber / $_repeatCount',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _repeatCoachingMessage(),
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _voiceCommandCard(bool needsRetake) {
    final commands = _voiceCommands(needsRetake);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic_none_rounded),
              const SizedBox(width: 8),
              const Text(
                '말로도 선택할 수 있어요',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (_speechReady)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _listening
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
            children: commands
                .map(
                  (cmd) => Container(
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
                  cmd,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2F67B2),
                  ),
                ),
              ),
            )
                .toList(),
          ),
          const SizedBox(height: 12),
          Text(
            _speechReady
                ? '원하는 버튼 대신 위 단어를 말해 보세요.'
                : '이 기기에서는 음성 인식을 사용할 수 없어요.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
          if (_lastRecognizedWords.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '인식된 말: $_lastRecognizedWords',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5B6676),
              ),
            ),
          ],
          if (_speechReady) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _startListening(needsRetake: needsRetake),
                icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                label: Text(_listening ? '듣는 중' : '음성으로 선택하기'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _repeatNextCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '다음 반복',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_nextRepeatNumber번째 반복',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '준비되시면 다음 버튼을 누르거나 "다음"이라고 말씀해 주세요.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _routineNextCard(int? nextRoutineExerciseId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isLastRoutineItem ? '오늘의 운동 완료' : '다음 운동',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isLastRoutineItem
                ? '모든 추천 운동을 완료했어요.'
                : _exerciseName(nextRoutineExerciseId ?? 0),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isLastRoutineItem
                ? '$_secondsLeft초 후 결과 화면으로 이동합니다.'
                : '$_secondsLeft초 후 다음 운동으로 자동 진행합니다.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recommendedNextCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '다음 추천 운동',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _exerciseName(_recommendedExerciseId()),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _recommendedReason(),
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$_secondsLeft초 후 자동으로 시작합니다.',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5B8DEF),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsRetake = _quality['needsRetake'] == true;
    final nextRoutineExerciseId = _nextRoutineExerciseId();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isRepeatMode ? '반복 $_currentRepeatNumber / $_repeatCount 결과' : '운동 결과',
        ),
      ),
      body: SafeArea(
        child: _saving
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '저장 실패: $_error',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        )
            : LayoutBuilder(
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
                    if (!needsRetake && _hasMoreRepeats)
                      _repeatSummaryCard()
                    else
                      _resultSummaryCard(needsRetake),

                    if (!needsRetake) ...[
                      const SizedBox(height: 14),
                      _taskResultCard(),
                    ],

                    const SizedBox(height: 14),

                    _voiceCommandCard(needsRetake),

                    const SizedBox(height: 14),

                    Text(
                      _hasMoreRepeats ? '이번 반복에서 확인한 점' : '세부 결과',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),

                    const SizedBox(height: 10),

                    _scoreTile(_labelForScore('rom'), _rom),
                    const SizedBox(height: 8),
                    _scoreTile(
                      _labelForScore('compensation'),
                      _compensation,
                    ),
                    const SizedBox(height: 8),
                    _scoreTile(_labelForScore('symmetry'), _symmetry),
                    const SizedBox(height: 8),
                    _scoreTile(_labelForScore('smoothness'), _smoothness),
                    const SizedBox(height: 8),
                    _scoreTile(_labelForScore('timing'), _timing),

                    if (needsRetake) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFFFD6A5),
                          ),
                        ),
                        child: Text(
                          _retakeMessage(),
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    if (!needsRetake && _hasMoreRepeats) ...[
                      _repeatNextCard(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _goNextRepeat,
                          child: Text('$_nextRepeatNumber번째 따라하기 시작'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            _autoTimer?.cancel();
                            _stopListening();
                            context.go('/exercise', extra: {
                              'patientId': _patientId,
                              'affectedSide': _affectedSide,
                            });
                          },
                          child: const Text('운동 선택으로'),
                        ),
                      ),
                    ] else if (!needsRetake && _hasRoutine) ...[
                      _routineNextCard(nextRoutineExerciseId),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _goNextRoutineStep,
                          child: Text(
                            _isLastRoutineItem
                                ? '결과 보기'
                                : '${_exerciseName(nextRoutineExerciseId ?? 0)} 시작',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            _autoTimer?.cancel();
                            _stopListening();
                            context.go('/results', extra: {
                              'patientId': _patientId,
                              'sessionUuid': _sessionUuid,
                              'affectedSide': _affectedSide,
                            });
                          },
                          child: const Text('오늘 운동 종료'),
                        ),
                      ),
                    ] else if (!needsRetake) ...[
                      _recommendedNextCard(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _goRecommendedExercise,
                          child: Text(
                            '${_exerciseName(_recommendedExerciseId())} 지금 시작',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            _autoTimer?.cancel();
                            _stopListening();
                            context.go('/exercise', extra: {
                              'patientId': _patientId,
                              'affectedSide': _affectedSide,
                            });
                          },
                          child: const Text('운동 직접 선택'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            _autoTimer?.cancel();
                            _stopListening();
                            context.go('/results', extra: {
                              'patientId': _patientId,
                              'sessionUuid': _sessionUuid,
                              'affectedSide': _affectedSide,
                            });
                          },
                          child: const Text('오늘은 여기까지'),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _retryCurrentExercise,
                          child: const Text('다시 시작하기'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MockResult {
  final int overall;
  final int symmetry;
  final int timing;
  final int smoothness;
  final int compensation;
  final int rom;

  final int taskTargetCount;
  final int taskSuccessCount;
  final double taskSuccessRate;
  final double taskScore;
  final double finalTaskOrientedScore;

  final Map<String, dynamic> quality;
  final Map<String, dynamic> features;

  _MockResult({
    required this.overall,
    required this.symmetry,
    required this.timing,
    required this.smoothness,
    required this.compensation,
    required this.rom,
    required this.taskTargetCount,
    required this.taskSuccessCount,
    required this.taskSuccessRate,
    required this.taskScore,
    required this.finalTaskOrientedScore,
    required this.quality,
    required this.features,
  });
}