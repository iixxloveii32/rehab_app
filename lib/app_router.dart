import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import 'ui/app_scaffold_body.dart';
import 'ui/responsive.dart';
import 'config/app_config.dart';
import 'exercises/exercise_definitions.dart';
import 'models/patient.dart';
import 'screens/exercise_select_page.dart';
import 'screens/feedback_screen.dart';
import 'screens/exercise_history_page.dart';
import 'screens/patient_list_screen.dart';
import 'screens/results_page.dart';
import 'screens/screening_analyze_screen.dart';
import 'screens/screening_camera_screen.dart';
import 'screens/screening_result_page.dart';
import 'screens/screening_screen.dart';
import 'storage/patient_store.dart';
import 'utils/voice_guide.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/patient-list',
  routes: [
    GoRoute(
      path: '/patient-form',
      builder: (context, state) => const PatientFormScreen(),
    ),
    GoRoute(
      path: '/patient-list',
      builder: (context, state) => const PatientListScreen(),
    ),
    GoRoute(
      path: '/record',
      builder: (context, state) => const RecordingScreen(),
    ),
    GoRoute(
      path: '/review',
      builder: (context, state) => const ReviewScreen(),
    ),
    GoRoute(
      path: '/imitate',
      builder: (context, state) => const ImitationScreen(),
    ),
    GoRoute(
      path: '/feedback',
      builder: (context, state) => const FeedbackScreen(),
    ),
    GoRoute(
      path: '/results',
      builder: (context, state) => const ResultsPage(),
    ),
    GoRoute(
      path: '/exercise',
      builder: (context, state) => const ExerciseSelectPage(),
    ),
    GoRoute(
      path: '/exercise-history',
      builder: (context, state) => const ExerciseHistoryPage(),
    ),
    GoRoute(
      path: '/screening',
      builder: (context, state) => const ScreeningScreen(),
    ),
    GoRoute(
      path: '/screening-camera',
      builder: (context, state) => const ScreeningCameraScreen(),
    ),
    GoRoute(
      path: '/screening-analyze',
      builder: (context, state) => const ScreeningAnalyzeScreen(),
    ),
    GoRoute(
      path: '/screening-result',
      builder: (context, state) => const ScreeningResultPage(),
    ),
  ],
);

Map? _routeExtra(BuildContext context) {
  final extra = GoRouterState.of(context).extra;
  return extra is Map ? extra : null;
}

class _PreviewFrame extends StatelessWidget {
  final Widget child;
  final double aspectRatio;

  const _PreviewFrame({
    super.key,
    required this.child,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
              color: Colors.black,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

double _cameraAspectRatioForScreen(BuildContext context, CameraController c) {
  final raw = c.value.aspectRatio;
  final orientation = MediaQuery.of(context).orientation;
  if (orientation == Orientation.portrait) {
    return 1 / raw;
  }
  return raw;
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

Future<void> _applyExerciseSpecificZoom(
    CameraController controller,
    int exerciseId,
    ) async {
  try {
    final minZoom = await controller.getMinZoomLevel();
    final maxZoom = await controller.getMaxZoomLevel();

    double targetZoom = 1.0;

    if (exerciseId == 1 || exerciseId == 5) {
      // 팔 옆으로 들기와 옆으로 손 뻗기는 좌우 움직임 반경이 커서,
      // 기기가 지원하는 가장 넓은 화각에 가깝게 잡는다.
      targetZoom = minZoom < 0.7 ? 0.7 : minZoom;
    }

    if (targetZoom < minZoom) {
      targetZoom = minZoom;
    }

    if (targetZoom > maxZoom) {
      targetZoom = maxZoom;
    }

    await controller.setZoomLevel(targetZoom);
  } catch (_) {
    // 줌 조절을 지원하지 않는 기기에서는 기본 카메라 상태를 유지한다.
  }
}

class _PatientPositionGuide extends StatelessWidget {
  const _PatientPositionGuide();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-0.84, 0),
            child: Container(
              width: 1.2,
              height: double.infinity,
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          Align(
            alignment: const Alignment(0.84, 0),
            child: Container(
              width: 1.2,
              height: double.infinity,
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.84),
            child: Container(
              width: double.infinity,
              height: 1.2,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.93),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.44),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '팔 전체가 화면 안에 보이게 해 주세요',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTargetOverlay extends StatelessWidget {
  final int exerciseId;
  final String affectedSide;

  const _TaskTargetOverlay({
    required this.exerciseId,
    required this.affectedSide,
  });

  @override
  Widget build(BuildContext context) {
    final cue = _targetForExercise(exerciseId, affectedSide);
    if (cue == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        painter: _TargetDotPainter(cue),
        child: const SizedBox.expand(),
      ),
    );
  }

  _TargetDot? _targetForExercise(int id, String side) {
    final normalizedSide = side.toUpperCase();
    final isLeftAffected = normalizedSide == 'L';

    // 환자 화면 기준: 좌측 환측은 화면 왼쪽, 우측 환측은 화면 오른쪽에 표시한다.
    final sideX = isLeftAffected ? 0.22 : 0.78;
    final sideUpperX = isLeftAffected ? 0.24 : 0.76;

    switch (id) {
      case 0:
        return const _TargetDot(
          position: Offset(0.50, 0.25),
          label: '위',
        );
      case 1:
        return _TargetDot(
          position: Offset(sideUpperX, 0.34),
          label: '옆',
        );
      case 2:
        return const _TargetDot(
          position: Offset(0.50, 0.29),
          label: '머리',
        );
      case 3:
      // 허리 뒤로 손 가져가기는 2D 화면상 목표점을 찍으면 오히려 혼란스러워서 표시하지 않는다.
        return null;
      case 4:
        return const _TargetDot(
          position: Offset(0.50, 0.39),
          label: '앞',
        );
      case 5:
        return _TargetDot(
          position: Offset(sideX, 0.47),
          label: '옆',
        );
      case 6:
        return const _TargetDot(
          position: Offset(0.50, 0.42),
          label: '입 앞',
        );
      case 7:
        return const _TargetDot(
          position: Offset(0.50, 0.38),
          label: '앞',
        );
      default:
        return const _TargetDot(
          position: Offset(0.50, 0.40),
          label: '목표',
        );
    }
  }
}

class _TargetDot {
  final Offset position;
  final String label;

  const _TargetDot({
    required this.position,
    required this.label,
  });
}

class _TargetDotPainter extends CustomPainter {
  final _TargetDot target;

  const _TargetDotPainter(this.target);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      target.position.dx * size.width,
      target.position.dy * size.height,
    );

    final pulsePaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 20, pulsePaint);

    final outerPaint = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, 12, outerPaint);

    final dotPaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.96)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 9, dotPaint);

    final innerPaint = Paint()
      ..color = Colors.white.withOpacity(0.96)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.2, innerPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: target.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black87,
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final dx = (center.dx - textPainter.width / 2)
        .clamp(8.0, size.width - textPainter.width - 8.0);
    final dy = (center.dy + 18)
        .clamp(8.0, size.height - textPainter.height - 8.0);

    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        dx - 7,
        dy - 3,
        textPainter.width + 14,
        textPainter.height + 6,
      ),
      const Radius.circular(999),
    );
    canvas.drawRRect(bg, Paint()..color = Colors.black.withOpacity(0.38));
    textPainter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _TargetDotPainter oldDelegate) {
    return oldDelegate.target != target;
  }
}

class StepHeader extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;

  const StepHeader({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.primary.withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$step / 4 단계',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusCard extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const StatusCard({
    super.key,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.primary.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _CompactStageHeader extends StatelessWidget {
  final String stage;
  final String title;
  final String? subtitle;
  final String? status;
  final Widget? trailing;

  const _CompactStageHeader({
    required this.stage,
    required this.title,
    this.subtitle,
    this.status,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displaySubtitle = status ?? subtitle ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.primary.withOpacity(0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              stage,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                if (displaySubtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    displaySubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: Color(0xFF5B6676),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({super.key});

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  String _sex = 'M';
  String _affectedSide = 'L';
  DateTime? _birthDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefillIfExists();
  }

  Future<void> _prefillIfExists() async {
    final existing = await PatientStore.load();
    if (!mounted || existing == null) return;
    setState(() {
      _nameCtrl.text = existing.name;
      _sex = existing.sex;
      _birthDate = existing.birthDate;
    });
  }

  void _handleBack() {
    context.go('/patient-list');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 40, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      locale: const Locale('ko', 'KR'),
    );

    if (picked == null) return;
    setState(() => _birthDate = picked);
  }

  Future<void> _onNext() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생년월일을 선택해 주세요.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final patient = Patient(
        name: _nameCtrl.text.trim(),
        sex: _sex,
        birthDate: _birthDate!,
        affectedSide: _affectedSide,
      );

      final patientId = await PatientStore.saveAndReturnId(patient);

      if (!mounted) return;
      context.go('/exercise', extra: {
        'patientId': patientId,
        'affectedSide': _affectedSide,
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _birthLabel() {
    if (_birthDate == null) return '생년월일 선택';
    final d = _birthDate!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
          title: const Text('사용자 정보 입력'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const StepHeader(
                              step: 1,
                              title: '사용자 정보를 입력해 주세요',
                              subtitle:
                              '이름, 성별, 생년월일, 환측 정보를 입력하면 운동을 시작할 수 있어요.',
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '이름',
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                hintText: '이름을 입력해 주세요',
                              ),
                              validator: (v) {
                                final t = (v ?? '').trim();
                                if (t.isEmpty) return '이름을 입력해 주세요.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '성별',
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('남'),
                                  selected: _sex == 'M',
                                  onSelected: (_) => setState(() => _sex = 'M'),
                                ),
                                ChoiceChip(
                                  label: const Text('여'),
                                  selected: _sex == 'F',
                                  onSelected: (_) => setState(() => _sex = 'F'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '환측',
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('좌측'),
                                  selected: _affectedSide == 'L',
                                  onSelected: (_) =>
                                      setState(() => _affectedSide = 'L'),
                                ),
                                ChoiceChip(
                                  label: const Text('우측'),
                                  selected: _affectedSide == 'R',
                                  onSelected: (_) =>
                                      setState(() => _affectedSide = 'R'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '생년월일',
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _pickBirthDate,
                                child: Text(_birthLabel()),
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _onNext,
                                child: Text(_saving ? '저장 중...' : '다음'),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  CameraController? _controller;

  bool _initializing = true;
  bool _recording = false;
  bool _finalizing = false;
  bool _autoFlowStarted = false;

  XFile? _videoFile;

  int _prepareSeconds = 3;
  int _recordSeconds = AppConfig.recordDurationSec;

  Timer? _prepareTimer;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front =
      cameras.where((c) => c.lensDirection == CameraLensDirection.front);
      final selected = front.isNotEmpty ? front.first : cameras.first;

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      final data = _routeExtra(context);
      final exerciseId = (data?['exerciseId'] as int?) ?? 0;
      await _applyExerciseSpecificZoom(controller, exerciseId);

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initializing = false;
      });

      final exercise = Exercises.byId(exerciseId);

      await VoiceGuide.speak(
        '건강한 팔로 촬영합니다. 처음 맞춘 위치에서 준비해 주세요.',
      );

      _startAutoFlow();
    } catch (e) {
      if (!mounted) return;
      setState(() => _initializing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카메라 초기화 실패: $e')),
      );
    }
  }

  Future<void> _cancelExercise() async {
    _prepareTimer?.cancel();
    _recordTimer?.cancel();
    await VoiceGuide.stop();

    if (!mounted) return;

    final data = _routeExtra(context);
    final int? patientId = data?['patientId'] as int?;
    final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';

    context.go('/exercise', extra: {
      'patientId': patientId,
      'affectedSide': affectedSide,
    });
  }

  @override
  void dispose() {
    _prepareTimer?.cancel();
    _recordTimer?.cancel();
    VoiceGuide.stop();
    _controller?.dispose();
    super.dispose();
  }

  void _startAutoFlow() async {
    if (_autoFlowStarted) return;
    _autoFlowStarted = true;

    await VoiceGuide.speak('3초 후 시작합니다.');

    if (!mounted) return;
    setState(() {
      _prepareSeconds = 3;
      _recording = false;
      _finalizing = false;
      _recordSeconds = AppConfig.recordDurationSec;
    });

    _prepareTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_prepareSeconds <= 1) {
        timer.cancel();
        setState(() {
          _prepareSeconds = 0;
        });
        VoiceGuide.speak('시작');
        await _startAutoRecord();
      } else {
        setState(() {
          _prepareSeconds -= 1;
        });
      }
    });
  }

  Future<void> _startAutoRecord() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    try {
      await c.prepareForVideoRecording();
      await c.startVideoRecording();

      if (!mounted) return;
      setState(() {
        _recording = true;
        _finalizing = false;
        _videoFile = null;
        _recordSeconds = AppConfig.recordDurationSec;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_recordSeconds <= 1) {
          timer.cancel();
          await _stopAutoRecordAndGoNext();
        } else {
          setState(() {
            _recordSeconds -= 1;
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('자동 녹화 시작 실패: $e')),
      );
    }
  }

  Future<void> _stopAutoRecordAndGoNext() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || !_recording) return;

    try {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _finalizing = true;
      });

      final file = await c.stopVideoRecording();

      if (!mounted) return;
      setState(() {
        _finalizing = false;
        _videoFile = file;
      });

      _goNext();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _finalizing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('자동 녹화 종료 실패: $e')),
      );
    }
  }

  void _goNext() {
    final path = _videoFile?.path;
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('촬영된 영상이 없습니다.')),
      );
      return;
    }

    final data = _routeExtra(context);

    final patientId = data?['patientId'] as int?;
    final exerciseId = data?['exerciseId'] as int?;
    final sessionUuid = data?['sessionUuid'] as String?;
    final affectedSide = data?['affectedSide'] as String?;

    context.go('/review', extra: {
      'videoPath': path,
      'referenceVideoPath': path,
      'patientId': patientId,
      'exerciseId': exerciseId,
      'sessionUuid': sessionUuid,
      'affectedSide': affectedSide,
      'routineExerciseIds': data?['routineExerciseIds'],
      'routineIndex': data?['routineIndex'],
      'fromRoutine': data?['fromRoutine'],
      'repeatCount': data?['repeatCount'] ?? 1,
      'repeatIndex': data?['repeatIndex'] ?? 0,
    });
  }

  String _statusText() {
    if (_initializing) return '촬영 화면을 준비하고 있어요.';
    if (_prepareSeconds > 0 && !_recording && !_finalizing) {
      return '준비해 주세요. ($_prepareSeconds)';
    }
    if (_recording) {
      return '건강한 쪽 팔로 천천히 움직여 주세요. 남은 시간: $_recordSeconds초';
    }
    if (_finalizing) {
      return '촬영을 마무리하고 있어요.';
    }
    return '촬영을 준비하고 있어요.';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final data = _routeExtra(context);
    final exerciseId = (data?['exerciseId'] as int?) ?? 0;
    final affectedSide = (data?['affectedSide'] as String?) ?? 'L';
    final exercise = Exercises.byId(exerciseId);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _cancelExercise();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('촬영하기'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _cancelExercise,
          ),
        ),
        body: _initializing
            ? const Center(child: CircularProgressIndicator())
            : (c == null || !c.value.isInitialized)
            ? const Center(child: Text('카메라를 사용할 수 없습니다.'))
            : Column(
          children: [
            AppScaffoldBody(
              safeBottom: false,
              padding: EdgeInsets.fromLTRB(
                Responsive.horizontalPadding(context),
                12,
                Responsive.horizontalPadding(context),
                8,
              ),
              child: Column(
                children: [
                  _CompactStageHeader(
                    stage: '건강한 팔 촬영',
                    title: exercise.taskTitle,
                    status: _statusText(),
                    trailing: _recording
                        ? const Icon(Icons.fiber_manual_record, color: Colors.red)
                        : null,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PreviewFrame(
                    aspectRatio:
                    _cameraAspectRatioForScreen(context, c),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(c),
                        const _PatientPositionGuide(),
                        if (_prepareSeconds <= 0)
                          _TaskTargetOverlay(
                            exerciseId: exerciseId,
                            affectedSide: affectedSide,
                          ),
                      ],
                    ),
                  ),
                  if (_prepareSeconds > 0 &&
                      !_recording &&
                      !_finalizing)
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.45),
                        ),
                        child: Center(
                          child: Text(
                            '$_prepareSeconds',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_recording)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.60),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '남은 시간 $_recordSeconds초',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _cancelExercise,
                    child: const Text('운동 중단하기'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  VideoPlayerController? _vc;
  bool _loading = true;
  bool _mirror = true;
  bool _navigating = false;
  bool _guideFinished = false;

  int _playCount = 0;
  final int _targetPlayCount = AppConfig.reviewRepeatCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      await VoiceGuide.stop();
      await Future.delayed(const Duration(milliseconds: 300));

      final data = _routeExtra(context);
      final path = data?['videoPath'] as String?;
      final exerciseId = (data?['exerciseId'] as int?) ?? 0;
      final exercise = Exercises.byId(exerciseId);

      debugPrint('================ REVIEW INIT START ================');
      debugPrint('review extra: $data');
      debugPrint('review videoPath: $path');

      if (path == null || path.isEmpty) {
        throw Exception('videoPath가 전달되지 않았습니다.');
      }

      final f = File(path);

      debugPrint('review file exists: ${f.existsSync()}');

      if (f.existsSync()) {
        debugPrint('review file size: ${f.lengthSync()} bytes');
      }

      if (!f.existsSync()) {
        throw Exception('영상 파일이 존재하지 않습니다: $path');
      }

      final controller = VideoPlayerController.file(f);

      debugPrint('review controller created, initialize start');

      await controller.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('영상 초기화 시간이 초과되었습니다.'),
      );
      await controller.setVolume(0.0);

      debugPrint('review initialize success');
      debugPrint(
        'review duration: ${controller.value.duration.inMilliseconds} ms',
      );
      debugPrint('review aspectRatio: ${controller.value.aspectRatio}');

      await controller.setLooping(false);
      controller.addListener(_handleVideoProgress);

      if (!mounted) return;
      setState(() {
        _vc = controller;
        _loading = false;
        _guideFinished = false;
        _playCount = 0;
      });

      await Future.delayed(const Duration(milliseconds: 300));

      await VoiceGuide.speak(
        '영상을 보며 움직임을 기억해 주세요.',
      );

      if (!mounted || _navigating) return;
      setState(() {
        _guideFinished = true;
      });

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted || _navigating) return;

      await controller.seekTo(Duration.zero);
      await controller.play();

      debugPrint('review play start after voice guide');
      debugPrint('================ REVIEW INIT END =================');
    } catch (e, st) {
      debugPrint('================ REVIEW INIT ERROR ===============');
      debugPrint('review init error: $e');
      debugPrint('$st');

      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('관찰 영상 로드 실패: $e')),
      );
    }
  }

  void _handleVideoProgress() async {
    final vc = _vc;
    if (vc == null || !vc.value.isInitialized || _navigating) return;
    if (!_guideFinished) return;
    if (!vc.value.isPlaying) return;

    final position = vc.value.position;
    final duration = vc.value.duration;
    if (duration.inMilliseconds <= 0) return;

    final ended = position.inMilliseconds >= duration.inMilliseconds - 150;
    if (!ended) return;

    debugPrint(
      'review ended detected: playCount=$_playCount, '
          'position=${position.inMilliseconds}, duration=${duration.inMilliseconds}',
    );

    await vc.pause();

    if (_playCount < _targetPlayCount - 1) {
      _playCount += 1;
      await vc.seekTo(Duration.zero);
      if (!mounted || _navigating) return;
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted || _navigating) return;
      await vc.play();
      debugPrint('review replay start: ${_playCount + 1} / $_targetPlayCount');
      return;
    }

    debugPrint('review finished all repeats, go imitate');
    await _goImitate();
  }

  Future<void> _cancelExercise() async {
    _navigating = true;
    await VoiceGuide.stop();

    if (!mounted) return;

    final data = _routeExtra(context);
    final int? patientId = data?['patientId'] as int?;
    final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';

    context.go('/exercise', extra: {
      'patientId': patientId,
      'affectedSide': affectedSide,
    });
  }

  Future<void> _goImitate() async {
    if (_navigating) return;
    _navigating = true;

    debugPrint('review go imitate start');

    final vc = _vc;
    if (vc != null && vc.value.isInitialized) {
      await vc.pause();
    }

    await VoiceGuide.stop();
    await VoiceGuide.speak('이제 환측 팔로 따라해 볼게요.');

    final data = _routeExtra(context);
    final path = data?['videoPath'] as String?;
    final referenceVideoPath = data?['referenceVideoPath'] as String? ?? path;

    final patientId = data?['patientId'] as int?;
    final affectedSide = data?['affectedSide'] as String?;
    final exerciseId = data?['exerciseId'] as int?;
    final sessionUuid = data?['sessionUuid'] as String?;

    debugPrint('review -> imitate videoPath: $path');
    debugPrint('review -> imitate referenceVideoPath: $referenceVideoPath');

    if (path == null) return;
    if (!mounted) return;

    context.go('/imitate', extra: {
      'videoPath': path,
      'referenceVideoPath': referenceVideoPath,
      'patientId': patientId,
      'exerciseId': exerciseId,
      'sessionUuid': sessionUuid,
      'affectedSide': affectedSide,
      'routineExerciseIds': data?['routineExerciseIds'],
      'routineIndex': data?['routineIndex'],
      'fromRoutine': data?['fromRoutine'],
      'repeatCount': data?['repeatCount'] ?? 1,
      'repeatIndex': data?['repeatIndex'] ?? 0,
    });
  }

  @override
  void dispose() {
    _navigating = true;
    _vc?.removeListener(_handleVideoProgress);
    VoiceGuide.stop();
    _vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = _vc;
    final data = _routeExtra(context);
    final exerciseId = (data?['exerciseId'] as int?) ?? 0;
    final exercise = Exercises.byId(exerciseId);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _cancelExercise();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('관찰하기'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _cancelExercise,
          ),
          actions: [
            Row(
              children: [
                const Text(
                  '좌우반전',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Switch(
                  value: _mirror,
                  onChanged: (v) => setState(() => _mirror = v),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (vc == null || !vc.value.isInitialized)
            ? const Center(child: Text('영상을 불러오지 못했습니다.'))
            : SafeArea(
          child: Column(
            children: [
              AppScaffoldBody(
                safeBottom: false,
                padding: EdgeInsets.fromLTRB(
                  Responsive.horizontalPadding(context),
                  12,
                  Responsive.horizontalPadding(context),
                  8,
                ),
                child: Column(
                  children: [
                    _CompactStageHeader(
                      stage: '거울 영상 관찰',
                      title: exercise.taskTitle,
                      status: _guideFinished
                          ? '움직임을 기억해 주세요'
                          : '잠시 후 재생됩니다',
                      trailing: Text(
                        _guideFinished ? '${_playCount + 1} / $_targetPlayCount' : '대기',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: vc.value.aspectRatio,
                        child: Container(
                          color: Colors.black,
                          child: Transform.flip(
                            flipX: _mirror,
                            child: VideoPlayer(vc),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Responsive.horizontalPadding(context),
              8,
              Responsive.horizontalPadding(context),
              16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _goImitate,
                child: const Text('바로 따라하기'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ImitationScreen extends StatefulWidget {
  const ImitationScreen({super.key});

  @override
  State<ImitationScreen> createState() => _ImitationScreenState();
}

class _ImitationScreenState extends State<ImitationScreen> {
  VideoPlayerController? _vc;
  CameraController? _cc;

  bool _loading = true;
  bool _recording = false;
  bool _autoFlowStarted = false;

  XFile? _patientVideo;

  int _prepareSeconds = 3;
  int _recordSeconds = AppConfig.imitateDurationSec;

  Timer? _prepareTimer;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _prepareTimer?.cancel();
    _recordTimer?.cancel();
    VoiceGuide.stop();
    _vc?.dispose();
    _cc?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final data = _routeExtra(context);
    final path = data?['videoPath'] as String?;
    final referenceVideoPath = data?['referenceVideoPath'] as String? ?? path;
    final exerciseId = (data?['exerciseId'] as int?) ?? 0;

    if (referenceVideoPath == null ||
        referenceVideoPath.isEmpty ||
        !File(referenceVideoPath).existsSync()) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영상 경로가 없습니다.')),
      );
      return;
    }

    try {
      final vc = VideoPlayerController.file(File(referenceVideoPath));
      await vc.initialize();
      await vc.setVolume(0.0);
      await vc.setLooping(true);

      final cameras = await availableCameras();
      final front =
      cameras.where((c) => c.lensDirection == CameraLensDirection.front);
      final selected = front.isNotEmpty ? front.first : cameras.first;

      final cc = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await cc.initialize();
      await _applyExerciseSpecificZoom(cc, exerciseId);

      if (!mounted) return;
      setState(() {
        _vc = vc;
        _cc = cc;
        _loading = false;
      });

      _startAutoFlow();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('초기화 실패: $e')),
      );
    }
  }

  Future<void> _cancelExercise() async {
    _prepareTimer?.cancel();
    _recordTimer?.cancel();
    await VoiceGuide.stop();

    if (!mounted) return;

    final data = _routeExtra(context);
    final int? patientId = data?['patientId'] as int?;
    final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';

    context.go('/exercise', extra: {
      'patientId': patientId,
      'affectedSide': affectedSide,
    });
  }

  void _startAutoFlow() async {
    if (_autoFlowStarted) return;
    _autoFlowStarted = true;

    final data = _routeExtra(context);
    final exerciseId = (data?['exerciseId'] as int?) ?? 0;
    final exercise = Exercises.byId(exerciseId);

    await VoiceGuide.speak(
      '환측 팔로 따라합니다. 처음 맞춘 위치에서 준비해 주세요.',
    );

    if (!mounted) return;
    setState(() {
      _prepareSeconds = 3;
      _recordSeconds = AppConfig.imitateDurationSec;
    });

    _prepareTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_prepareSeconds <= 1) {
        timer.cancel();
        setState(() => _prepareSeconds = 0);
        VoiceGuide.speak('시작');
        await _startAutoImitation();
      } else {
        setState(() => _prepareSeconds -= 1);
      }
    });
  }

  Future<void> _startAutoImitation() async {
    final vc = _vc;
    final cc = _cc;
    if (vc == null || cc == null) return;
    if (!vc.value.isInitialized || !cc.value.isInitialized) return;

    try {
      await vc.seekTo(Duration.zero);
      await vc.play();

      await cc.prepareForVideoRecording();
      await cc.startVideoRecording();

      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordSeconds = AppConfig.imitateDurationSec;
        _patientVideo = null;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_recordSeconds <= 1) {
          timer.cancel();
          await _stopAutoImitationAndGoFeedback();
        } else {
          setState(() => _recordSeconds -= 1);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('자동 따라하기 시작 실패: $e')),
      );
    }
  }

  Future<void> _stopAutoImitationAndGoFeedback() async {
    final cc = _cc;
    if (cc == null || !cc.value.isInitialized || !_recording) return;

    try {
      final file = await cc.stopVideoRecording();

      if (!mounted) return;
      setState(() {
        _recording = false;
        _patientVideo = file;
      });

      _goFeedback();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('자동 따라하기 종료 실패: $e')),
      );
    }
  }

  Future<void> _goFeedback() async {
    final data = _routeExtra(context);

    final modelPath = data?['videoPath'] as String?;
    final referenceVideoPath =
        data?['referenceVideoPath'] as String? ?? modelPath;

    final patientId = data?['patientId'] as int?;
    final affectedSide = data?['affectedSide'] as String?;
    final exerciseId = data?['exerciseId'] as int?;
    final sessionUuid = data?['sessionUuid'] as String?;
    final patientPath = _patientVideo?.path;

    if (modelPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모델 영상이 없습니다.')),
      );
      return;
    }

    if (patientPath == null || !File(patientPath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('환자 영상이 없습니다.')),
      );
      return;
    }

    await VoiceGuide.speak('잘하셨습니다. 결과를 분석합니다.');

    if (!mounted) return;
    context.go('/feedback', extra: {
      'patientId': patientId,
      'exerciseId': exerciseId,
      'sessionUuid': sessionUuid,
      'affectedSide': affectedSide,
      'modelPath': modelPath,
      'referenceVideoPath': referenceVideoPath,
      'patientPath': patientPath,
      'routineExerciseIds': data?['routineExerciseIds'],
      'routineIndex': data?['routineIndex'],
      'fromRoutine': data?['fromRoutine'],
      'repeatCount': data?['repeatCount'] ?? 1,
      'repeatIndex': data?['repeatIndex'] ?? 0,
    });
  }

  String _statusText() {
    if (_loading) return '따라하기 화면을 준비하고 있어요.';

    if (_recording) {
      return '환측 팔로 천천히 정확하게 반복해 주세요.';
    }

    if (_prepareSeconds > 0) return '준비해 주세요. ($_prepareSeconds)';

    return '녹화를 마무리하고 있어요.';
  }

  Widget _compactTaskHeader({
    required String taskTitle,
    required String exerciseName,
    required int targetCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFDCE6F2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            taskTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$exerciseName 운동',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5B6676),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _compactMetricBox(
                  label: '목표',
                  value: '1분 $targetCount회 이상',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactMetricBox(
                  label: '남은 시간',
                  value: '$_recordSeconds초',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '처음 맞춘 위치에서 천천히 따라해 주세요.',
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5B6676),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactMetricBox({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE3E8EF),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5B6676),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2F67B2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomGuideBar({
    required int targetCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _statusText(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _recording ? '$_recordSeconds초' : '대기',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _exampleVideoPip({
    required VideoPlayerController vc,
    required bool placeLeft,
    required bool isTablet,
  }) {
    final double pipWidth = isTablet ? 180 : 128;
    final double pipHeight = isTablet ? 240 : 170;

    return Positioned(
      top: 178,
      left: placeLeft ? 12 : null,
      right: placeLeft ? null : 12,
      child: Container(
        width: pipWidth,
        height: pipHeight,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: vc.value.size.width,
              height: vc.value.size.height,
              child: VideoPlayer(vc),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vc = _vc;
    final cc = _cc;
    final isTablet = Responsive.isTablet(context);
    final data = _routeExtra(context);
    final affectedSide = (data?['affectedSide'] as String?) ?? 'L';

    final exerciseId = (data?['exerciseId'] as int?) ?? 0;
    final exercise = Exercises.byId(exerciseId);

    final bool placePipLeft = affectedSide == 'R';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _cancelExercise();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('따라하기'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _cancelExercise,
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (vc == null || cc == null)
            ? const Center(child: Text('화면을 불러오지 못했습니다.'))
            : SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: _PreviewFrame(
                  aspectRatio:
                  _cameraAspectRatioForScreen(context, cc),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(cc),
                      const _PatientPositionGuide(),
                      if (_prepareSeconds <= 0)
                        _TaskTargetOverlay(
                          exerciseId: exerciseId,
                          affectedSide: affectedSide,
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _compactTaskHeader(
                  taskTitle: exercise.taskTitle,
                  exerciseName: exercise.name,
                  targetCount: exercise.taskTargetCount,
                ),
              ),
              _exampleVideoPip(
                vc: vc,
                placeLeft: placePipLeft,
                isTablet: isTablet,
              ),
              Positioned(
                top: 358,
                left: placePipLeft ? 12 : null,
                right: placePipLeft ? null : 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.90),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    '예시 영상',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF455468),
                    ),
                  ),
                ),
              ),
              if (_prepareSeconds > 0 && !_recording)
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.45),
                    ),
                    child: Center(
                      child: Text(
                        '$_prepareSeconds',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 88,
                child: _bottomGuideBar(
                  targetCount: exercise.taskTargetCount,
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _cancelExercise,
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                      Colors.white.withOpacity(0.94),
                      side: const BorderSide(
                        color: Color(0xFFDCE6F2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      '운동 중단하기',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}