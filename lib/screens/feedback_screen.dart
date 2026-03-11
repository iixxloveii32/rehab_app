import 'dart:convert';
import 'dart:io';
import 'package:isar/isar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../storage/isar_db.dart';
import '../models/session_log.dart';

String _serverBaseUrl() {
  return 'http://192.168.10.107:5000';
}

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

  int _overall = 0;
  int _symmetry = 0;
  int _timing = 0;
  int _smoothness = 0;
  int _compensation = 0;
  int _rom = 0;

  late String _affectedSide;

  String? _sessionUuid;
  int _attemptIndex = 0;

  Map<String, dynamic> _quality = <String, dynamic>{};
  Map<String, dynamic> _features = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveScore());
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
    if (_overall >= 85) return '아주 좋아요';
    if (_overall >= 70) return '잘했어요';
    if (_overall >= 50) return '조금 더 연습해볼게요';
    return '다시 해보면 더 좋아질 수 있어요';
  }

  String _scoreComment() {
    if ((_quality['needsRetake'] == true)) {
      return _retakeMessage();
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

  String _labelForScore(String key) {
    switch (key) {
      case 'rom':
        return '팔 올리기';
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

  Future<void> _saveScore() async {
    try {
      final extra = GoRouterState.of(context).extra;
      final data = (extra is Map) ? extra : null;

      final affectedSide = data?['affectedSide'] as String? ?? 'L';
      _affectedSide = affectedSide;

      final patientId = data?['patientId'] as int?;
      final modelPath = data?['modelPath'] as String?;
      final patientPath = data?['patientPath'] as String?;
      final exerciseId = (data?['exerciseId'] as int?) ?? 0;
      final incomingSessionUuid = data?['sessionUuid'] as String?;

      if (patientId == null) throw Exception('patientId가 없습니다.');
      if (modelPath == null || modelPath.isEmpty) throw Exception('modelPath가 없습니다.');
      if (patientPath == null || patientPath.isEmpty) throw Exception('patientPath가 없습니다.');

      _patientId = patientId;
      _exerciseId = exerciseId;

      final now = DateTime.now();
      final todayKey = _dateKey(now);
      final sessionUuid = incomingSessionUuid ?? DateTime.now().microsecondsSinceEpoch.toString();
      _sessionUuid = sessionUuid;

      final isar = IsarDB.instance;

      final allLogs = await isar.sessionLogs.where().findAll();

      final existingImitLogs = allLogs.where((log) =>
      log.patientId == patientId &&
          log.exerciseId == exerciseId &&
          log.dateKey == todayKey &&
          log.isReference == false).toList();

      final attemptIndex = existingImitLogs.length + 1;
      _attemptIndex = attemptIndex;

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
      _quality = result.quality;
      _features = result.features;

      final existingRefs = allLogs.where((log) =>
      log.sessionUuid == sessionUuid &&
          log.isReference == true).toList();

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
        ..attemptIndex = attemptIndex
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
    final uri = Uri.parse('${_serverBaseUrl()}/analyze');

    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('reference', referenceVideoPath))
      ..files.add(await http.MultipartFile.fromPath('imitation', imitationVideoPath))
      ..fields['exerciseId'] = _exerciseId.toString()
      ..fields['affectedSide'] = _affectedSide;

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      throw Exception('분석 서버 오류 ${resp.statusCode}: ${resp.body}');
    }

    final j = jsonDecode(resp.body) as Map<String, dynamic>;

    final features = (j['features'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final quality = (j['quality'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    int asInt(dynamic v) => (v is num) ? v.round() : int.parse(v.toString());

    return _MockResult(
      overall: asInt(j['overall']),
      symmetry: asInt(j['symmetry']),
      timing: asInt(j['timing']),
      smoothness: asInt(j['smoothness']),
      compensation: asInt(j['compensation']),
      rom: asInt(j['rom']),
      quality: quality,
      features: features,
    );
  }

  Widget _scoreChip(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$value점',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsRetake = _quality['needsRetake'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('피드백')),
      body: SafeArea(
        child: _saving
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('저장 실패: $_error'),
          ),
        )
            : Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _scoreTitle(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          '총점',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_overall점',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _scoreComment(),
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '세부 결과',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    _scoreChip(_labelForScore('rom'), _rom),
                    const SizedBox(height: 10),
                    _scoreChip(_labelForScore('compensation'), _compensation),
                    const SizedBox(height: 10),
                    _scoreChip(_labelForScore('symmetry'), _symmetry),
                    const SizedBox(height: 10),
                    _scoreChip(_labelForScore('smoothness'), _smoothness),
                    const SizedBox(height: 10),
                    _scoreChip(_labelForScore('timing'), _timing),
                    if (needsRetake) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          _retakeMessage(),
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    context.push('/results', extra: {
                      'patientId': _patientId,
                    });
                  },
                  child: const Text('결과 보기'),
                ),
              ),
            ],
          ),
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
  final Map<String, dynamic> quality;
  final Map<String, dynamic> features;

  _MockResult({
    required this.overall,
    required this.symmetry,
    required this.timing,
    required this.smoothness,
    required this.compensation,
    required this.rom,
    required this.quality,
    required this.features,
  });
}