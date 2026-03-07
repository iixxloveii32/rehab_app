import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';

import '../models/session_log.dart';
import '../storage/isar_db.dart';

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

  String _affectedSide = 'L';
  String? _sessionUuid;
  int _attemptIndex = 0;

  Map<String, dynamic> _lastFeatures = {};
  Map<String, dynamic> _lastQuality = {};

  String _exerciseTitle() {
    switch (_exerciseId) {
      case 0:
        return '팔 앞으로 들기';
      case 1:
        return '팔 옆으로 들기';
      case 2:
        return '머리 만지기';
      case 3:
        return '허리 뒤로 손 가져가기';
      case 4:
        return '앞 물건 잡기';
      case 5:
        return '옆 물건 잡기';
      case 6:
        return '팔 굽히기';
      case 7:
        return '팔 펴기';
      default:
        return '운동';
    }
  }

  String _romLabel() {
    switch (_exerciseId) {
      case 0:
        return '팔 올리기';
      case 1:
        return '옆으로 올리기';
      case 2:
        return '머리까지 닿기';
      case 3:
        return '허리 뒤로 가기';
      case 4:
        return '앞으로 뻗기';
      case 5:
        return '옆으로 뻗기';
      case 6:
        return '팔 굽히기';
      case 7:
        return '팔 펴기';
      default:
        return '팔 움직임';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveScore());
  }

  List<String> buildCoachingLines(Map<String, dynamic> features) {
    final side = (features['affectedSide'] as String?) ?? _affectedSide;
    final sideKr = (side == 'R') ? '오른쪽 팔' : '왼쪽 팔';

    final romAff = (features['rom_aff'] is num)
        ? (features['rom_aff'] as num).toDouble()
        : null;
    final trunkDelta = (features['trunkDeltaDeg'] is num)
        ? (features['trunkDeltaDeg'] as num).toDouble()
        : 0.0;
    final shrugDelta = (features['shrugDelta'] is num)
        ? (features['shrugDelta'] as num).toDouble()
        : 0.0;
    final symDiff = (features['imi_symmetryDiffDeg'] is num)
        ? (features['imi_symmetryDiffDeg'] as num).toDouble()
        : 0.0;

    final lines = <String>[];

    switch (_exerciseId) {
      case 0: // 팔 앞으로 들기
        if (romAff != null) {
          if (romAff < 40) {
            lines.add('$sideKr을 몸 앞쪽으로 조금 더 높게 들어 보세요.');
          } else if (romAff < 70) {
            lines.add('$sideKr을 앞쪽으로 조금 더 끝까지 올려 보세요.');
          } else {
            lines.add('$sideKr을 앞쪽으로 잘 들어 올렸어요.');
          }
        }
        break;

      case 1: // 팔 옆으로 들기
        if (romAff != null) {
          if (romAff < 40) {
            lines.add('$sideKr을 몸 옆으로 조금 더 벌려 보세요.');
          } else if (romAff < 70) {
            lines.add('$sideKr을 옆으로 조금 더 높게 올려 보세요.');
          } else {
            lines.add('$sideKr을 옆으로 잘 들어 올렸어요.');
          }
        }
        break;

      case 2: // 머리 만지기
        if (romAff != null) {
          if (romAff < 40) {
            lines.add('$sideKr 손이 머리 쪽으로 조금 더 가까이 가면 좋아요.');
          } else if (romAff < 70) {
            lines.add('$sideKr 손을 머리 쪽으로 조금 더 올려 보세요.');
          } else {
            lines.add('$sideKr 손이 머리 쪽으로 잘 올라갔어요.');
          }
        }
        break;

      case 3: // 허리 뒤로 손 가져가기
        if (romAff != null) {
          if (romAff < 40) {
            lines.add('$sideKr 손을 허리 뒤쪽으로 조금 더 보내 보세요.');
          } else if (romAff < 70) {
            lines.add('$sideKr 손이 허리 뒤로 조금 더 가면 좋아요.');
          } else {
            lines.add('$sideKr 손이 허리 뒤로 잘 이동했어요.');
          }
        }
        break;

      case 4: // 앞 물건 잡기
        if (romAff != null) {
          if (romAff < 40) {
            lines.add('$sideKr을 앞쪽으로 조금 더 뻗어 보세요.');
          } else if (romAff < 70) {
            lines.add('$sideKr을 앞 목표까지 조금 더 뻗어 보세요.');
          } else {
            lines.add('$sideKr을 앞쪽으로 잘 뻗었어요.');
          }
        }
        break;

      case 5: // 옆 물건 잡기
        if (romAff != null) {
          if (romAff < 40) {
            lines.add('$sideKr을 옆쪽으로 조금 더 뻗어 보세요.');
          } else if (romAff < 70) {
            lines.add('$sideKr을 옆 목표까지 조금 더 뻗어 보세요.');
          } else {
            lines.add('$sideKr을 옆쪽으로 잘 뻗었어요.');
          }
        }
        break;

      case 6: // 팔 굽히기
        if (romAff != null) {
          if (romAff < 40) {
            lines.add('$sideKr을 조금 더 굽혀 보세요.');
          } else if (romAff < 70) {
            lines.add('$sideKr을 몸 쪽으로 조금 더 당겨 보세요.');
          } else {
            lines.add('$sideKr 굽히기가 잘 되었어요.');
          }
        }
        break;

      case 7: // 팔 펴기
        if (romAff != null) {
          if (romAff < 40) {
            lines.add('$sideKr을 조금 더 곧게 펴 보세요.');
          } else if (romAff < 70) {
            lines.add('$sideKr을 끝까지 조금 더 펴 보세요.');
          } else {
            lines.add('$sideKr 펴기가 잘 되었어요.');
          }
        }
        break;

      default:
        if (romAff != null) {
          if (romAff < 60) {
            lines.add('$sideKr 움직임을 조금 더 크게 해보세요.');
          } else {
            lines.add('$sideKr 움직임이 좋아요.');
          }
        }
    }

    if (trunkDelta >= 8) {
      lines.add('상체가 함께 많이 움직였어요. 몸통을 조금 더 고정해 보세요.');
    }

    if (shrugDelta >= 0.08) {
      lines.add('어깨에 힘이 많이 들어갔어요. 어깨를 내리고 편하게 해보세요.');
    }

    if (symDiff >= 12) {
      lines.add('좌우 차이가 조금 커요. 가능한 비슷한 높이와 범위로 맞춰보세요.');
    }

    if (lines.isEmpty) {
      lines.add('좋아요. 지금처럼 천천히 한 번 더 해보세요.');
    }

    return lines.take(3).toList();
  }

  String _scoreLabel(int score) {
    if (score >= 80) return '좋아요';
    if (score >= 60) return '잘하고 있어요';
    if (score >= 40) return '조금 더 연습해봐요';
    return '천천히 다시 해봐요';
  }

  Color _scoreColor(BuildContext context, int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.redAccent;
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

      final sessionUuid =
          incomingSessionUuid ?? DateTime.now().microsecondsSinceEpoch.toString();
      _sessionUuid = sessionUuid;

      final isar = IsarDB.instance;

      final existingImitLogs = await isar.sessionLogs
          .filter()
          .patientIdEqualTo(patientId)
          .exerciseIdEqualTo(exerciseId)
          .dateKeyEqualTo(todayKey)
          .isReferenceEqualTo(false)
          .findAll();

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
      _lastFeatures = result.features;
      _lastQuality = result.quality;

      final existingRefs = await isar.sessionLogs
          .filter()
          .sessionUuidEqualTo(sessionUuid)
          .isReferenceEqualTo(true)
          .findAll();

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
    } catch (e, st) {
      debugPrint('FeedbackScreen _saveScore error: $e');
      debugPrintStack(stackTrace: st);

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
    final baseUrl = _serverBaseUrl();
    final uri = Uri.parse('$baseUrl/analyze');

    debugPrint('SERVER baseUrl = $baseUrl');
    debugPrint('SERVER uri = $uri');
    debugPrint('reference path = $referenceVideoPath');
    debugPrint('imitation path = $imitationVideoPath');

    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('reference', referenceVideoPath))
      ..files.add(await http.MultipartFile.fromPath('imitation', imitationVideoPath))
      ..fields['exerciseId'] = _exerciseId.toString()
      ..fields['affectedSide'] = _affectedSide;

    debugPrint('sending request to server...');

    final streamed = await req.send().timeout(const Duration(seconds: 15));
    final resp = await http.Response.fromStream(streamed);

    debugPrint('server status = ${resp.statusCode}');
    debugPrint('server body = ${resp.body}');

    if (resp.statusCode == 501) {
      throw Exception('해당 동작 분석 알고리즘이 아직 준비되지 않았습니다.');
    }
    if (resp.statusCode != 200) {
      throw Exception('분석 서버 오류 ${resp.statusCode}: ${resp.body}');
    }

    final j = jsonDecode(resp.body) as Map<String, dynamic>;

    final features =
        (j['features'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final quality =
        (j['quality'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

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

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final showBottomButton = !_saving && _error == null;
    final coachingLines = buildCoachingLines(_lastFeatures);
    final needRetake = _lastQuality['needsRetake'] == true;

    return Scaffold(
      appBar: AppBar(title: Text('${_exerciseTitle()} 결과')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _saving
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
            ? Center(
          child: Text(
            '결과를 불러오지 못했습니다.\n$_error',
            textAlign: TextAlign.center,
          ),
        )
            : ListView(
          children: [
            _OverallScoreCard(
              score: _overall,
              label: _scoreLabel(_overall),
              color: _scoreColor(context, _overall),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _exerciseTitle(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniScoreCard(
                    title: _romLabel(),
                    score: _rom,
                    icon: Icons.swipe_up_alt,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniScoreCard(
                    title: '좌우 균형',
                    score: _symmetry,
                    icon: Icons.balance,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MiniScoreCard(
              title: '몸통 안정성',
              score: _compensation,
              icon: Icons.accessibility_new,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘의 안내',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    ...coachingLines.map(
                          (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(line)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (needRetake) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '움직임이 작거나 화면 인식이 어려웠어요. 다시 한 번 천천히 촬영해 보세요.',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: showBottomButton
          ? SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
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
        ),
      )
          : null,
    );
  }
}

class _OverallScoreCard extends StatelessWidget {
  final int score;
  final String label;
  final Color color;

  const _OverallScoreCard({
    required this.score,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Text(
              '전체 점수',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              '$score점',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniScoreCard extends StatelessWidget {
  final String title;
  final int score;
  final IconData icon;

  const _MiniScoreCard({
    required this.title,
    required this.score,
    required this.icon,
  });

  String _comment(int score) {
    if (score >= 80) return '좋아요';
    if (score >= 60) return '보통';
    return '연습 필요';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '$score점',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(_comment(score)),
          ],
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