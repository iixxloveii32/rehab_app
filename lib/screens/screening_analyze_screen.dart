import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../models/session_log.dart';
import '../storage/isar_db.dart';

String _serverBaseUrl() {
  return 'http://192.168.10.107:5000';
}

class ScreeningAnalyzeScreen extends StatefulWidget {
  const ScreeningAnalyzeScreen({super.key});

  @override
  State<ScreeningAnalyzeScreen> createState() => _ScreeningAnalyzeScreenState();
}

class _ScreeningAnalyzeScreenState extends State<ScreeningAnalyzeScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
  }

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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
      final int screeningTotal = (data?['screeningTotal'] as int?) ?? 5;
      final String screeningSessionUuid =
          (data?['screeningSessionUuid'] as String?) ?? '';
      final String? videoPath = data?['videoPath'] as String?;

      if (patientId == null) throw Exception('patientId가 없습니다.');
      if (videoPath == null || videoPath.isEmpty) {
        throw Exception('videoPath가 없습니다.');
      }

      final uri = Uri.parse('${_serverBaseUrl()}/screening_analyze');

      final req = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('video', videoPath))
        ..fields['exerciseId'] = exerciseId.toString()
        ..fields['affectedSide'] = affectedSide
        ..fields['functionKey'] = functionKey;

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode != 200) {
        throw Exception('스크리닝 분석 서버 오류 ${resp.statusCode}: ${resp.body}');
      }

      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final overall = (j['overall'] as num).round();
      final quality = (j['quality'] as Map?)?.cast<String, dynamic>() ?? {};
      final features = (j['features'] as Map?)?.cast<String, dynamic>() ?? {};

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
        })
        ..featuresJson = jsonEncode(features);

      final isar = IsarDB.instance;
      await isar.writeTxn(() async {
        await isar.sessionLogs.put(log);
      });

      if (!mounted) return;

      if (screeningIndex < screeningTotal - 1) {
        final nextItems = [0, 1, 2, 3, 4, 5, 6, 7];
    final nextExerciseId = nextItems[screeningIndex + 1];

    String nextTitle;
    String nextDesc;
    String nextFunctionKey;

    switch (nextExerciseId) {
    case 0:
    nextTitle = '팔 앞으로 들기';
    nextDesc = '가능한 만큼 팔을 앞으로 천천히 들어보세요.';
    nextFunctionKey = 'flexion';
    break;
    case 1:
    nextTitle = '팔 옆으로 들기';
    nextDesc = '가능한 만큼 팔을 옆으로 천천히 들어보세요.';
    nextFunctionKey = 'abduction';
    break;
    case 2:
    nextTitle = '머리 만지기';
    nextDesc = '손을 머리 쪽으로 천천히 가져가 보세요.';
    nextFunctionKey = 'hand_to_head';
    break;
    case 3:
    nextTitle = '허리 뒤로 손 가져가기';
    nextDesc = '손을 허리 뒤쪽으로 천천히 가져가 보세요.';
    nextFunctionKey = 'hand_to_back';
    break;
    case 4:
    nextTitle = '앞으로 손 뻗기';
    nextDesc = '화면의 목표 지점을 향해 손을 앞으로 뻗어보세요.';
    nextFunctionKey = 'reach_forward';
    break;
    case 5:
    nextTitle = '옆으로 손 뻗기';
    nextDesc = '화면의 목표 지점을 향해 손을 옆으로 뻗어보세요.';
    nextFunctionKey = 'reach_side';
    break;
    case 6:
    nextTitle = '팔 굽히기';
    nextDesc = '팔꿈치를 천천히 굽혀보세요.';
    nextFunctionKey = 'elbow_flexion';
    break;
    default:
    nextTitle = '팔 펴기';
    nextDesc = '팔꿈치를 천천히 펴보세요.';
    nextFunctionKey = 'elbow_extension';
    }

        context.go('/screening-camera', extra: {
          'patientId': patientId,
          'affectedSide': affectedSide,
          'exerciseId': nextExerciseId,
          'functionKey': nextFunctionKey,
          'title': nextTitle,
          'desc': nextDesc,
          'screeningIndex': screeningIndex + 1,
          'screeningTotal': screeningTotal,
          'screeningSessionUuid': screeningSessionUuid,
        });
      } else {
        context.go('/screening-result', extra: {
          'patientId': patientId,
          'affectedSide': affectedSide,
          'screeningSessionUuid': screeningSessionUuid,
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스크리닝 분석 중'),
      ),
      body: Center(
        child: _error != null
            ? Padding(
          padding: const EdgeInsets.all(20),
          child: Text('오류: $_error'),
        )
            : const CircularProgressIndicator(),
      ),
    );
  }
}