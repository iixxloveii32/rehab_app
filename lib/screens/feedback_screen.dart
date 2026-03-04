import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import '../storage/isar_db.dart';
import '../models/session_log.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

String _serverBaseUrl() {
  return 'http://192.168.219.103:5000';
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
  // ✅ B 구조용
  String? _sessionUuid;
  int _attemptIndex = 0;

  List<String> buildCoachingLines(Map<String, dynamic> features) {
    final side = (features['affectedSide'] ?? _affectedSide).toString();
    final romAff = (features['rom_aff'] is num) ? (features['rom_aff'] as num).toDouble() : null;
    final trunkDelta = (features['trunkDeltaDeg'] is num) ? (features['trunkDeltaDeg'] as num).toDouble() : 0.0;
    final shrugDelta = (features['shrugDelta'] is num) ? (features['shrugDelta'] as num).toDouble() : 0.0;
    final symDiff = (features['imi_symmetryDiffDeg'] is num) ? (features['imi_symmetryDiffDeg'] as num).toDouble() : 0.0;

    final sideKr = (side == 'R') ? '오른쪽(환측)' : '왼쪽(환측)';
    final lines = <String>[];

    if (romAff != null) {
      lines.add('$sideKr 거상 범위(ROM)가 기준 대비 ${romAff.toStringAsFixed(0)}% 입니다.');
      if (romAff < 60) {
        lines.add('팔을 더 높이 들어 올리는 연습이 필요합니다. (가능한 범위에서 천천히)');
      } else if (romAff < 80) {
        lines.add('거상 범위가 조금 부족합니다. 끝범위에서 1초 멈춤을 시도해보세요.');
      } else {
        lines.add('거상 범위가 좋습니다. 같은 높이를 안정적으로 반복해보세요.');
      }
    }

    if (trunkDelta >= 8) lines.add('몸통 기울기 보상이 증가했습니다(+${trunkDelta.toStringAsFixed(0)}°). 몸통을 고정해보세요.');
    if (shrugDelta >= 0.08) lines.add('어깨 으쓱(승모근) 보상이 증가했습니다. 어깨를 내리고 팔을 들어보세요.');
    if (symDiff >= 12) lines.add('좌우 높이 차이가 큽니다(${symDiff.toStringAsFixed(0)}°). 가능한 같은 높이로 맞춰보세요.');

    if (lines.length > 4) return lines.take(4).toList();
    return lines;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveScore());
  }

  Future<void> _saveScore() async {
    try {
      final extra = GoRouterState.of(context).extra;
      final data = (extra is Map) ? extra : null;
      final affectedSide = data?['affectedSide'] as String? ?? 'L';
      _affectedSide = affectedSide;

      final patientId = data?['patientId'] as int?;
      final modelPath = data?['modelPath'] as String?;   // reference
      final patientPath = data?['patientPath'] as String?; // imitation
      final exerciseId = (data?['exerciseId'] as int?) ?? 0;

      // (옵션) 상위 화면에서 sessionUuid를 넘기고 있으면 그걸 사용
      final incomingSessionUuid = data?['sessionUuid'] as String?;

      if (patientId == null) throw Exception('patientId가 없습니다.');
      if (modelPath == null || modelPath.isEmpty) throw Exception('modelPath가 없습니다.');
      if (patientPath == null || patientPath.isEmpty) throw Exception('patientPath가 없습니다.');

      _patientId = patientId;
      _exerciseId = exerciseId;

      final now = DateTime.now(); // 현재 KST 환경 전제
      final todayKey = _dateKey(now);

      // ✅ sessionUuid는 "ref + imit"을 묶는 키 (한 번 정하면 고정)
      final sessionUuid = incomingSessionUuid ?? DateTime.now().microsecondsSinceEpoch.toString();
      _sessionUuid = sessionUuid;

      final isar = IsarDB.instance;

      // ✅ imitation attemptIndex 계산: 오늘/환자/동작에서 imitation 로그 개수 + 1
      // (ref는 제외)
      final existingImitLogs = await isar.sessionLogs
          .filter()
          .patientIdEqualTo(patientId)
          .exerciseIdEqualTo(exerciseId)
          .dateKeyEqualTo(todayKey)
          .isReferenceEqualTo(false)
          .findAll();

      final attemptIndex = existingImitLogs.length + 1;

      _attemptIndex = attemptIndex;

      // ✅ Mock 분석(서버 없이도 "파일이 같으면 점수도 같게")
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

      // ✅ 1) reference 로그: 하루에 여러 번 찍을 수 있으니 "sessionUuid 기준으로 1개만" 저장
      // 이미 같은 sessionUuid로 ref가 저장되어 있으면 스킵
      final existingRefs = await isar.sessionLogs
          .filter()
          .sessionUuidEqualTo(sessionUuid)
          .isReferenceEqualTo(true)
          .findAll();

      final refExists = existingRefs.isNotEmpty;

      // ✅ 2) imitation 로그: 매 시도마다 저장
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

  // 파일 기반 “일관된” mock 분석
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
    final streamed = await req.send().timeout(const Duration(minutes: 3));
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode == 501) {
      // TODO: 사용자에게 “해당 동작 분석 준비중” 표시
      throw Exception('해당 동작 분석 알고리즘이 아직 준비되지 않았습니다.');
    }
    if (resp.statusCode != 200) {
      throw Exception('분석 서버 오류 ${resp.statusCode}: ${resp.body}');
    }

    final j = jsonDecode(resp.body) as Map<String, dynamic>;

    final features = (j['features'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final quality = (j['quality'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    int asInt(dynamic v) => (v is num) ? v.round() : int.parse(v.toString());

    final overall = asInt(j['overall']);
    final symmetry = asInt(j['symmetry']);
    final timing = asInt(j['timing']);
    final smoothness = asInt(j['smoothness']);
    final compensation = asInt(j['compensation']);
    final rom = asInt(j['rom']);

    return _MockResult(
      overall: overall,
      symmetry: symmetry,
      timing: timing,
      smoothness: smoothness,
      compensation: compensation,
      rom: rom,
      quality: quality,
      features: features,
    );
  }

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('피드백')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _saving
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
            ? Text('저장 실패: $_error')
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('저장 완료 (patientId=$_patientId, exerciseId=$_exerciseId)'),
            const SizedBox(height: 8),
            Text('sessionUuid: $_sessionUuid'),
            Text('attemptIndex: $_attemptIndex'),
            const SizedBox(height: 12),
            Text('overall: $_overall'),
            Text('symmetry: $_symmetry'),
            Text('timing: $_timing'),
            Text('smoothness: $_smoothness'),
            Text('compensation: $_compensation'),
            Text('rom: $_rom'),
            Text('DEBUG affectedSide=$_affectedSide'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.go('/results', extra: {
                    'patientId': _patientId,
                  });
                },
                child: const Text('결과 보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockResult {
  final int overall, symmetry, timing, smoothness, compensation, rom;
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