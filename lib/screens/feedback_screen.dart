import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:video_player/video_player.dart';

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

  VideoPlayerController? _analysisVideoController;
  bool _analysisVideoReady = false;

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
    _analysisVideoController?.dispose();
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
    if (_hasMoreRepeats) {
      return '"다음"이라고 말하면 다음 반복을 시작합니다.';
    }

    if (_hasRoutine) {
      if (_isLastRoutineItem) {
        return '"결과"라고 말하면 결과 화면으로 이동합니다.';
      }
      return '"다음"이라고 말하면 다음 운동을 시작합니다.';
    }

    return '"다음"이라고 말하면 추천 운동을 시작합니다.';
  }

  List<String> _voiceCommands(bool needsRetake) {
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

    _secondsLeft = AppConfig.feedbackAutoNextSec;

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


  Future<void> _prepareAnalysisVideo(String patientPath) async {
    if (patientPath.isEmpty || !File(patientPath).existsSync()) return;

    try {
      final oldController = _analysisVideoController;
      _analysisVideoController = null;
      _analysisVideoReady = false;
      await oldController?.dispose();

      final controller = VideoPlayerController.file(File(patientPath));
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0.0);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _analysisVideoController = controller;
        _analysisVideoReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _analysisVideoReady = false;
      });
    }
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

      await _prepareAnalysisVideo(patientPath);

      unawaited(
        VoiceGuide.speak(
          '분석 중입니다. 방금 따라한 동작을 다시 보며 기다려 주세요.',
        ),
      );

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

      final qualityForSave = <String, dynamic>{
        ...result.quality,
        'needsRetake': false,
        'scoreAsPerformed': true,
        'retakePolicy': 'disabled_score_all_performance',
      };

      _quality = qualityForSave;
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
        ..qualityJson = jsonEncode(qualityForSave)
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
        ..qualityJson = jsonEncode(qualityForSave)
        ..featuresJson = jsonEncode(result.features);

      await isar.writeTxn(() async {
        if (!refExists) {
          await isar.sessionLogs.put(refLog);
        }
        await isar.sessionLogs.put(imitLog);
      });

      try {
        await _analysisVideoController?.pause();
      } catch (_) {}

      await VoiceGuide.stop();

      if (!mounted) return;
      setState(() => _saving = false);

      const needsRetake = false;

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


    final streamed = await req.send().timeout(const Duration(seconds: 180));
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
    final ratio = (value / 100.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E8EF)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: ratio,
                backgroundColor: const Color(0xFFE9EEF5),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              '$value점',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreListCard(bool needsRetake) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            needsRetake ? '확인된 세부 결과' : '세부 결과',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _scoreTile(_labelForScore('rom'), _rom),
          const SizedBox(height: 6),
          _scoreTile(_labelForScore('compensation'), _compensation),
          const SizedBox(height: 6),
          _scoreTile(_labelForScore('symmetry'), _symmetry),
          const SizedBox(height: 6),
          _scoreTile(_labelForScore('smoothness'), _smoothness),
          const SizedBox(height: 6),
          _scoreTile(_labelForScore('timing'), _timing),
        ],
      ),
    );
  }

  Widget _resultSummaryCard(bool needsRetake) {
    final color = needsRetake ? const Color(0xFFFFF3E8) : const Color(0xFFEAF2FF);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 78,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Text(
                  '총점',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_overall',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const Text(
                  '점',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _scoreTitle(),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _scoreComment(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  needsRetake
                      ? '$_secondsLeft초 후 같은 운동을 다시 시작합니다'
                      : '$_secondsLeft초 후 자동으로 넘어갑니다',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2F67B2),
                  ),
                ),
              ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8EF)),
      ),
      child: Row(
        children: [
          Expanded(child: _taskMiniText('목표', '${_taskTargetCount}회')),
          Expanded(child: _taskMiniText('성공', '${_taskSuccessCount}회')),
          Expanded(child: _taskMiniText('달성률', '$percent%')),
          Expanded(child: _taskMiniText('최종', '${_finalTaskOrientedScore.round()}점')),
        ],
      ),
    );
  }

  Widget _taskMiniText(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5B6676),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Color(0xFF2F67B2),
          ),
        ),
      ],
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
    final commands = _voiceCommands(needsRetake).map((e) => '“$e”').join(' / ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Row(
        children: [
          Icon(
            _listening ? Icons.mic : Icons.mic_none_rounded,
            size: 18,
            color: _listening ? const Color(0xFF3FAE6F) : const Color(0xFF5B6676),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _speechReady ? '말로도 가능: $commands' : '음성 인식 사용 불가',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF455468),
              ),
            ),
          ),
          if (_lastRecognizedWords.isNotEmpty)
            Text(
              _lastRecognizedWords,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5B6676),
              ),
            ),
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


  Widget _analysisWaitingView() {
    final controller = _analysisVideoController;
    final hasVideo = _analysisVideoReady &&
        controller != null &&
        controller.value.isInitialized;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '결과를 분석하고 있어요',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '방금 따라한 동작을 다시 보며 기다려 주세요.\n분석이 끝나면 자동으로 결과가 표시됩니다.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: hasVideo
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    color: Colors.black,
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                )
                    : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFF),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFFDCE6F2),
                    ),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.video_library_outlined,
                        size: 42,
                        color: Color(0xFF5B8DEF),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '수행 영상을 준비하고 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE3E8EF)),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '분석이 끝나면 자동으로 결과가 표시됩니다.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const needsRetake = false;
    final nextRoutineExerciseId = _nextRoutineExerciseId();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isRepeatMode ? '반복 $_currentRepeatNumber / $_repeatCount 결과' : '운동 결과',
        ),
      ),
      body: SafeArea(
        child: _saving
            ? _analysisWaitingView()
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
                      const SizedBox(height: 8),
                      _taskResultCard(),
                    ],

                    const SizedBox(height: 8),
                    _scoreListCard(needsRetake),

                    const SizedBox(height: 8),
                    _voiceCommandCard(needsRetake),

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