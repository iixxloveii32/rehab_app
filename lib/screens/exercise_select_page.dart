import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../exercises/exercise_definitions.dart';
import '../models/session_log.dart';
import '../storage/isar_db.dart';
import '../ui/app_scaffold_body.dart';
import '../ui/responsive.dart';
import '../utils/voice_guide.dart';

class ExerciseSelectPage extends StatefulWidget {
  const ExerciseSelectPage({super.key});

  @override
  State<ExerciseSelectPage> createState() => _ExerciseSelectPageState();
}

class _ExerciseSelectPageState extends State<ExerciseSelectPage> {
  List<int> _recommendedIds = [];
  bool _loadingRecommendations = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadRecommendedExercises();
      if (!mounted) return;
      setState(() {
        _loadingRecommendations = false;
      });
    });
  }

  void _handleBack() {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;

    final int? patientId = data?['patientId'] as int?;
    final String? affectedSide = data?['affectedSide'] as String?;

    context.go('/patient-list', extra: {
      if (patientId != null) 'patientId': patientId,
      if (affectedSide != null) 'affectedSide': affectedSide,
    });
  }

  Future<void> _loadRecommendedExercises() async {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;
    final int? patientId = data?['patientId'] as int?;

    if (patientId == null) return;

    final isar = IsarDB.instance;
    final logs = await isar.sessionLogs.where().findAll();

    final screeningLogs = logs
        .where((e) =>
    e.patientId == patientId &&
        e.sessionUuid.startsWith('screening_') &&
        e.isReference == false)
        .toList();

    if (screeningLogs.isEmpty) return;

    screeningLogs.sort((a, b) => b.timestampKst.compareTo(a.timestampKst));
    final latest = screeningLogs.first.sessionUuid;

    final latestLogs =
    screeningLogs.where((e) => e.sessionUuid == latest).toList();

    latestLogs.sort((a, b) => a.overall.compareTo(b.overall));

    if (!mounted) return;
    setState(() {
      _recommendedIds =
          latestLogs.map((e) => e.exerciseId).toSet().take(3).toList();
    });
  }

  void _startRoutine(int? patientId, String affectedSide) {
    if (patientId == null || _recommendedIds.isEmpty) return;

    final sessionUuid = DateTime.now().microsecondsSinceEpoch.toString();

    context.go('/record', extra: {
      'patientId': patientId,
      'exerciseId': _recommendedIds.first,
      'sessionUuid': sessionUuid,
      'affectedSide': affectedSide,
      'routineExerciseIds': _recommendedIds,
      'routineIndex': 0,
      'fromRoutine': true,
      'repeatCount': 1,
      'repeatIndex': 0,
      'referenceVideoPath': null,
    });
  }

  Future<void> _showRepeatCountSheet(
      dynamic ex,
      int? patientId,
      String affectedSide,
      ) async {
    final repeatCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _RepeatCountSheet(
        exerciseName: ex.name as String,
      ),
    );

    if (repeatCount == null) return;

    final sessionUuid = DateTime.now().microsecondsSinceEpoch.toString();

    if (!mounted) return;
    context.go('/record', extra: {
      'patientId': patientId,
      'exerciseId': ex.id,
      'sessionUuid': sessionUuid,
      'affectedSide': affectedSide,
      'repeatCount': repeatCount,
      'repeatIndex': 0,
      'referenceVideoPath': null,
      'fromRoutine': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;

    final int? patientId = data?['patientId'] as int?;
    final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';
    final items = Exercises.list;

    final isTablet = Responsive.isTablet(context);
    final sectionGap = Responsive.sectionSpacing(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: const Text('운동 시작하기'),
        ),
        body: AppScaffoldBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('현재 상태 확인'),
              const SizedBox(height: 8),
              _screeningCard(patientId, affectedSide),
              SizedBox(height: sectionGap),
              _sectionTitle('오늘의 운동'),
              const SizedBox(height: 8),
              if (_loadingRecommendations)
                _infoCard('추천 운동을 불러오는 중입니다...')
              else if (_recommendedIds.isEmpty)
                _infoCard('먼저 현재 상태 평가를 진행해 주세요.')
              else ...[
                  _recommendedList(items),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _startRoutine(patientId, affectedSide),
                      child: const Text('오늘의 운동 시작하기'),
                    ),
                  ),
                ],
              SizedBox(height: sectionGap),
              _sectionTitle('전체 운동'),
              const SizedBox(height: 8),
              Expanded(
                child: isTablet
                    ? GridView.builder(
                  itemCount: items.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.65,
                  ),
                  itemBuilder: (context, index) {
                    final ex = items[index];
                    return _exerciseCard(ex, patientId, affectedSide);
                  },
                )
                    : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final ex = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _exerciseCard(ex, patientId, affectedSide),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Builder(
      builder: (context) => Text(
        text,
        style: TextStyle(
          fontSize: Responsive.titleFontSize(context),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoCard(String text) {
    return Builder(
      builder: (context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(Responsive.isTablet(context) ? 18 : 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FA),
          borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: Responsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _screeningCard(int? patientId, String? affectedSide) {
    return Builder(
      builder: (context) => InkWell(
        onTap: () async {
          await context.push('/screening', extra: {
            'patientId': patientId,
            'affectedSide': affectedSide,
          });
          if (mounted) {
            await _loadRecommendedExercises();
          }
        },
        borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
        child: Container(
          padding: EdgeInsets.all(Responsive.isTablet(context) ? 20 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE3E8EF)),
          ),
          child: Row(
            children: [
              Container(
                width: Responsive.isTablet(context) ? 56 : 48,
                height: Responsive.isTablet(context) ? 56 : 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius:
                  BorderRadius.circular(Responsive.isTablet(context) ? 16 : 14),
                ),
                child: const Icon(Icons.assignment_turned_in_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '현재 상태 평가하기\n간단한 동작으로 기능을 확인해요',
                  style: TextStyle(
                    fontSize: Responsive.bodyFontSize(context),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recommendedList(List items) {
    return Column(
      children: _recommendedIds.map((id) {
        final ex = items.firstWhere((e) => e.id == id);
        return _recommendCard(ex);
      }).toList(),
    );
  }

  Widget _recommendCard(dynamic ex) {
    return Builder(
      builder: (context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(Responsive.isTablet(context) ? 18 : 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
          color: const Color(0xFFEAF2FF),
        ),
        child: Row(
          children: [
            const Icon(Icons.star, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ex.name,
                style: TextStyle(
                  fontSize: Responsive.bodyFontSize(context) + 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseCard(dynamic ex, int? patientId, String affectedSide) {
    return Builder(
      builder: (context) => InkWell(
        onTap: () => _showRepeatCountSheet(ex, patientId, affectedSide),
        borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
        child: Container(
          padding: EdgeInsets.all(Responsive.isTablet(context) ? 18 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE3E8EF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ex.name,
                style: TextStyle(
                  fontSize: Responsive.bodyFontSize(context) + 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ex.desc,
                maxLines: Responsive.isTablet(context) ? 3 : null,
                overflow: Responsive.isTablet(context)
                    ? TextOverflow.ellipsis
                    : TextOverflow.visible,
                style: TextStyle(
                  fontSize: Responsive.bodyFontSize(context) - 1,
                  height: 1.4,
                  color: const Color(0xFF5B6676),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '눌러서 반복 횟수를 선택하세요',
                style: TextStyle(
                  fontSize: Responsive.bodyFontSize(context) - 2,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5B8DEF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepeatCountSheet extends StatefulWidget {
  final String exerciseName;

  const _RepeatCountSheet({
    required this.exerciseName,
  });

  @override
  State<_RepeatCountSheet> createState() => _RepeatCountSheetState();
}

class _RepeatCountSheetState extends State<_RepeatCountSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _speechReady = false;
  bool _listening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeechAndGuide();
  }

  @override
  void dispose() {
    _stopListening();
    VoiceGuide.stop();
    super.dispose();
  }

  Future<void> _initSpeechAndGuide() async {
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

      await VoiceGuide.speak(
        '반복할 횟수를 말씀해 주세요. 한 번, 두 번, 세 번 중에서 선택할 수 있어요.',
      );

      if (_speechReady) {
        await _startListening();
      }
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

  String _normalize(String text) {
    return text
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll('\n', '')
        .trim()
        .toLowerCase();
  }

  int? _parseRepeatCount(String text) {
    final normalized = _normalize(text);

    if (normalized.contains('한번') ||
        normalized.contains('1번') ||
        normalized == '1' ||
        normalized.contains('한개') ||
        normalized.contains('한회') ||
        normalized.contains('1회')) {
      return 1;
    }

    if (normalized.contains('두번') ||
        normalized.contains('2번') ||
        normalized == '2' ||
        normalized.contains('두개') ||
        normalized.contains('두회') ||
        normalized.contains('2회')) {
      return 2;
    }

    if (normalized.contains('세번') ||
        normalized.contains('3번') ||
        normalized == '3' ||
        normalized.contains('세개') ||
        normalized.contains('세회') ||
        normalized.contains('3회')) {
      return 3;
    }

    return null;
  }

  Future<void> _startListening() async {
    if (!_speechReady) return;

    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();

          if (!mounted) return;
          setState(() {
            _lastWords = words;
          });

          if (words.isEmpty) return;

          final parsed = _parseRepeatCount(words);
          if (parsed != null) {
            Navigator.of(context).pop(parsed);
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

  Widget _countButton(int count) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(count),
        child: Text('$count회'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.maxContentWidth(context),
          ),
          child: Container(
            margin: EdgeInsets.all(Responsive.horizontalPadding(context)),
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.exerciseName,
                  style: TextStyle(
                    fontSize: Responsive.largeTitleFontSize(context) - 2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '반복할 횟수를 선택해 주세요.',
                  style: TextStyle(
                    fontSize: Responsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFDCE6F2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.mic_none_rounded),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '말로도 선택할 수 있어요',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
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
                        children: const [
                          Chip(label: Text('한 번')),
                          Chip(label: Text('두 번')),
                          Chip(label: Text('세 번')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _speechReady
                            ? '한 번, 두 번, 세 번 중에서 말씀해 주세요.'
                            : '이 기기에서는 음성 인식을 사용할 수 없어요.',
                        style: TextStyle(
                          fontSize: Responsive.bodyFontSize(context) - 1,
                          height: 1.4,
                        ),
                      ),
                      if (_lastWords.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          '인식된 말: $_lastWords',
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
                            onPressed: _startListening,
                            icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                            label: Text(_listening ? '듣는 중' : '음성으로 선택하기'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _countButton(1),
                const SizedBox(height: 10),
                _countButton(2),
                const SizedBox(height: 10),
                _countButton(3),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}