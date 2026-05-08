import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../models/session_log.dart';
import '../storage/isar_db.dart';
import '../utils/voice_guide.dart';
import 'screening_plan.dart';
import '../config/app_config.dart';

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

  int _screeningScoreFromOverall(int overall) {
    if (overall >= 70) return 3;
    if (overall >= 40) return 2;
    if (overall >= 15) return 1;
    return 0;
  }

  void _cancelEvaluation() {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;

    final int? patientId = data?['patientId'] as int?;
    final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';

    context.go('/exercise', extra: {
      'patientId': patientId,
      'affectedSide': affectedSide,
      'fromScreening': true,
    });
  }

  Future<void> _analyze() async {
    try {
      final extra = GoRouterState.of(context).extra;
      final data = (extra is Map) ? extra : null;

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
                  ?.map((k, v) => MapEntry('$k', v as int)) ??
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
          _statusText = '상지 기능을 분석하고 있습니다.';
        });
      }

      final uri = Uri.parse(AppConfig.analyzeEndpoint);

      final req = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('reference', videoPath))
        ..files.add(await http.MultipartFile.fromPath('imitation', videoPath))
        ..fields['exerciseId'] = exerciseId.toString()
        ..fields['affectedSide'] = affectedSide
        ..fields['functionKey'] = functionKey
        ..fields['isScreening'] = 'true';

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode != 200) {
        throw Exception('스크리닝 분석 서버 오류 ${resp.statusCode}: ${resp.body}');
      }

      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final rawOverall = (j['overall'] as num).round();
      final overall = _screeningScoreFromOverall(rawOverall);

      final quality = (j['quality'] as Map?)?.cast<String, dynamic>() ?? {};
      final features = (j['features'] as Map?)?.cast<String, dynamic>() ?? {};

      final updatedScores = Map<String, int>.from(screeningScores);
      updatedScores[functionKey] = overall;

      final now = DateTime.now();
      final log = SessionLog()
        ..patientId = patientId
        ..exerciseId = exerciseId
        ..timestampKst = now
        ..dateKey = _dateKey(now)
        ..sessionUuid = screeningSessionUuid
        ..isReference = false
        ..attemptIndex = screeningIndex + 1
        ..overall = overall
        ..symmetry = overall
        ..timing = overall
        ..smoothness = overall
        ..compensation = overall
        ..rom = overall
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
        _statusText = isLast
            ? '평가 결과를 정리하고 있습니다.'
            : '다음 동작 화면으로 이동합니다.';
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _finishing = false;
        _error = e.toString();
      });
    }
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
        body: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '오류: $_error',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
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
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      _finishing ? '분석이 완료되었습니다.' : '상지 기능을 분석하고 있습니다.',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$stepText 동작',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}