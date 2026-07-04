import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/session_log.dart';
import '../storage/isar_db.dart';
import '../utils/voice_guide.dart';
import 'screening_plan.dart';

class ScreeningAnalyzeScreen extends StatefulWidget {
  const ScreeningAnalyzeScreen({super.key});

  @override
  State<ScreeningAnalyzeScreen> createState() => _ScreeningAnalyzeScreenState();
}

class _ScreeningAnalyzeScreenState extends State<ScreeningAnalyzeScreen> {
  bool _loading = true;
  bool _finishing = false;
  String? _error;

  int _screeningIndex = 0;
  int _screeningTotal = screeningFunctionItems.length;
  String _statusText = '상지 기능을 분석하고 있습니다.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
  }

  @override
  void dispose() {
    VoiceGuide.stop();
    super.dispose();
  }

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map? _routeData() {
    final extra = GoRouterState.of(context).extra;
    return extra is Map ? extra : null;
  }

  void _cancelEvaluation() {
    final data = _routeData();

    final int? patientId = data?['patientId'] as int?;
    final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';

    context.go('/exercise', extra: {
      'patientId': patientId,
      'affectedSide': affectedSide,
      'fromScreening': true,
    });
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? fallback;
  }

  Future<void> _analyze() async {
    try {
      final data = _routeData();

      final int? patientId = data?['patientId'] as int?;
      final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';
      final int exerciseId = (data?['exerciseId'] as int?) ?? 0;
      final String functionKey = (data?['functionKey'] as String?) ?? '';
      final int screeningIndex = (data?['screeningIndex'] as int?) ?? 0;
      final int screeningTotal =
          (data?['screeningTotal'] as int?) ?? screeningFunctionItems.length;
      final String screeningSessionUuid =
          (data?['screeningSessionUuid'] as String?) ?? '';
      final Map<String, int> screeningScores =
          (data?['screeningScores'] as Map?)
              ?.map((k, v) => MapEntry('$k', _asInt(v))) ??
              <String, int>{};
      final String? videoPath = data?['videoPath'] as String?;

      if (patientId == null) {
        throw Exception('patientId가 없습니다.');
      }
      if (videoPath == null || videoPath.isEmpty) {
        throw Exception('videoPath가 없습니다.');
      }
      if (functionKey.isEmpty) {
        throw Exception('functionKey가 없습니다.');
      }

      if (mounted) {
        setState(() {
          _screeningIndex = screeningIndex;
          _screeningTotal = screeningTotal;
          _loading = true;
          _finishing = false;
          _statusText = '촬영한 동작을 분석하고 있습니다.';
        });
      }

      final uri = Uri.parse(AppConfig.analyzeEndpoint);

      final req = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('reference', videoPath))
        ..files.add(await http.MultipartFile.fromPath('imitation', videoPath))
        ..fields['exerciseId'] = exerciseId.toString()
        ..fields['affectedSide'] = affectedSide
        ..fields['functionKey'] = functionKey
        ..fields['isScreening'] = 'true'
        ..fields['taskStandardVersion'] = AppConfig.taskStandardVersion
        ..fields['scoreSchemaVersion'] = AppConfig.scoreSchemaVersion.toString()
        ..fields['appVersion'] = AppConfig.appVersion;

      final streamed = await req.send().timeout(const Duration(seconds: 180));
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode != 200) {
        throw Exception('스크리닝 분석 서버 오류 ${resp.statusCode}: ${resp.body}');
      }

      final j = jsonDecode(resp.body) as Map<String, dynamic>;

      // 평가 결과 화면에서는 환자가 이해하기 쉬운 100점 기준 점수를 보여준다.
      // 낮은 점수 3개를 오늘 추천운동으로 사용하므로, 0~3 등급으로 변환하지 않는다.
      final int rawOverall = _asInt(j['overall']).clamp(0, 100);

      final quality = (j['quality'] as Map?)?.cast<String, dynamic>() ?? {};
      final features = (j['features'] as Map?)?.cast<String, dynamic>() ?? {};

      final updatedScores = Map<String, int>.from(screeningScores);
      updatedScores[functionKey] = rawOverall;

      final now = DateTime.now();
      final log = SessionLog()
        ..patientId = patientId
        ..exerciseId = exerciseId
        ..timestampKst = now
        ..dateKey = _dateKey(now)
        ..sessionUuid = screeningSessionUuid
        ..isReference = false
        ..attemptIndex = screeningIndex + 1
        ..overall = rawOverall
        ..symmetry = rawOverall
        ..timing = rawOverall
        ..smoothness = rawOverall
        ..compensation = rawOverall
        ..rom = rawOverall
        ..referenceVideoPath = null
        ..imitationVideoPath = videoPath
        ..qualityJson = jsonEncode({
          ...quality,
          'isScreening': true,
          'functionKey': functionKey,
          'rawOverall': rawOverall,
        })
        ..featuresJson = jsonEncode(features);

      final isar = IsarDB.instance;
      await isar.writeTxn(() async {
        await isar.sessionLogs.put(log);
      });

      if (!mounted) return;

      final bool isLast = screeningIndex >= screeningTotal - 1;

      setState(() {
        _loading = false;
        _finishing = true;
        _statusText = isLast ? '평가 결과를 정리하고 있습니다.' : '다음 동작으로 이동합니다.';
      });

      if (isLast) {
        await VoiceGuide.speak('평가가 끝났습니다. 결과를 확인합니다.');
        if (!mounted) return;

        context.go('/screening-result', extra: {
          'patientId': patientId,
          'affectedSide': affectedSide,
          'screeningSessionUuid': screeningSessionUuid,
          'screeningScores': updatedScores,
        });
        return;
      }

      final nextIndex = screeningIndex + 1;
      final nextItem = screeningFunctionItems[nextIndex];

      if (!mounted) return;

      context.go('/screening-camera', extra: {
        'patientId': patientId,
        'affectedSide': affectedSide,
        'screeningIndex': nextIndex,
        'screeningTotal': screeningTotal,
        'screeningSessionUuid': screeningSessionUuid,
        'screeningScores': updatedScores,
        'exerciseId': nextItem.exerciseId,
        'functionKey': nextItem.functionKey,
        'title': nextItem.title,
        'desc': nextItem.desc,
        'fromAutoFlow': true,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _finishing = false;
        _error = e.toString();
        _statusText = '분석 중 오류가 발생했습니다.';
      });
    }
  }

  Widget _loadingView(String stepText) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 22),
        Text(
          _finishing ? '분석이 완료되었습니다' : '상지 기능을 분석하고 있습니다',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$stepText 동작',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5B6676),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            _statusText,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _errorView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 46,
            color: Color(0xFFE57373),
          ),
          const SizedBox(height: 14),
          const Text(
            '분석에 실패했습니다',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF5B6676),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 180,
            height: 48,
            child: OutlinedButton(
              onPressed: _cancelEvaluation,
              child: const Text('평가 종료'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepText = '${_screeningIndex + 1} / $_screeningTotal';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancelEvaluation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('상지 기능 분석'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _cancelEvaluation,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: _error != null ? _errorView() : _loadingView(stepText),
          ),
        ),
      ),
    );
  }
}
