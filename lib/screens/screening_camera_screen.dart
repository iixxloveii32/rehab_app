import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/voice_guide.dart';
import 'screening_plan.dart';

class ScreeningCameraScreen extends StatefulWidget {
  const ScreeningCameraScreen({super.key});

  @override
  State<ScreeningCameraScreen> createState() => _ScreeningCameraScreenState();
}

class _ScreeningCameraScreenState extends State<ScreeningCameraScreen> {
  static const int _prepareDefaultSec = 3;
  static const int _recordDefaultSec = 5;

  CameraController? _controller;
  bool _initializing = true;
  bool _recording = false;
  bool _autoFlowStarted = false;
  bool _finalizing = false;

  XFile? _videoFile;

  int _prepareSeconds = _prepareDefaultSec;
  int _recordSeconds = _recordDefaultSec;

  Timer? _prepareTimer;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _prepareTimer?.cancel();
    _recordTimer?.cancel();
    VoiceGuide.stop();
    _controller?.dispose();
    super.dispose();
  }

  Map? _routeData() {
    final extra = GoRouterState.of(context).extra;
    return extra is Map ? extra : null;
  }

  int _screeningIndex() {
    final data = _routeData();
    final rawIndex = (data?['screeningIndex'] as int?) ?? 0;
    if (rawIndex < 0) return 0;
    if (rawIndex >= screeningFunctionItems.length) {
      return screeningFunctionItems.length - 1;
    }
    return rawIndex;
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

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initializing = false;
      });

      _startAutoFlow();
    } catch (e) {
      if (!mounted) return;
      setState(() => _initializing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카메라 초기화 실패: $e')),
      );
    }
  }

  Future<void> _startAutoFlow() async {
    if (_autoFlowStarted) return;
    _autoFlowStarted = true;

    final currentItem = screeningFunctionItems[_screeningIndex()];

    await VoiceGuide.speak(currentItem.voiceGuide);
    if (!mounted) return;

    await VoiceGuide.speak('3초 후 시작합니다.');
    if (!mounted) return;

    setState(() {
      _prepareSeconds = _prepareDefaultSec;
      _recordSeconds = _recordDefaultSec;
      _recording = false;
      _finalizing = false;
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
        await _startRecordingAuto();
      } else {
        setState(() {
          _prepareSeconds -= 1;
        });
      }
    });
  }

  Future<void> _startRecordingAuto() async {
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
        _recordSeconds = _recordDefaultSec;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_recordSeconds <= 1) {
          timer.cancel();
          await _stopRecordingAutoAndAnalyze();
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

  Future<void> _stopRecordingAutoAndAnalyze() async {
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

      _goAnalyze();
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

  Future<void> _cancelEvaluation() async {
    _prepareTimer?.cancel();
    _recordTimer?.cancel();
    await VoiceGuide.stop();

    if (!mounted) return;

    final data = _routeData();
    final int? patientId = data?['patientId'] as int?;
    final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';

    context.go('/exercise', extra: {
      'patientId': patientId,
      'affectedSide': affectedSide,
      'fromScreening': true,
    });
  }

  void _goAnalyze() {
    final data = _routeData();

    final int? patientId = data?['patientId'] as int?;
    final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';

    final int screeningIndex = _screeningIndex();
    final int screeningTotal =
        (data?['screeningTotal'] as int?) ?? screeningFunctionItems.length;
    final String screeningSessionUuid =
        (data?['screeningSessionUuid'] as String?) ?? '';
    final Map<String, int> screeningScores = (data?['screeningScores'] as Map?)
        ?.map((k, v) => MapEntry('$k', v as int)) ??
        <String, int>{};

    final currentItem = screeningFunctionItems[screeningIndex];

    final path = _videoFile?.path;
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('촬영된 영상이 없습니다.')),
      );
      return;
    }

    context.go('/screening-analyze', extra: {
      'patientId': patientId,
      'affectedSide': affectedSide,
      'exerciseId': currentItem.exerciseId,
      'functionKey': currentItem.functionKey,
      'title': currentItem.title,
      'desc': currentItem.desc,
      'screeningIndex': screeningIndex,
      'screeningTotal': screeningTotal,
      'screeningSessionUuid': screeningSessionUuid,
      'screeningScores': screeningScores,
      'videoPath': path,
    });
  }

  String _statusText() {
    if (_initializing) return '카메라 준비 중';
    if (_recording) return '동작 수행 중';
    if (_finalizing) return '촬영 마무리 중';
    if (_prepareSeconds > 0) return '$_prepareSeconds초 후 시작';
    return '영상 확인 중';
  }

  Widget _cameraPreviewArea() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: Text('카메라를 사용할 수 없습니다.'));
    }

    final currentItem = screeningFunctionItems[_screeningIndex()];

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = c.value.previewSize;
        final cameraAspectRatio = c.value.aspectRatio;

        double previewWidth = constraints.maxWidth;
        double previewHeight = constraints.maxHeight;

        if (previewSize != null) {
          final isPortrait =
              MediaQuery.of(context).orientation == Orientation.portrait;

          final double sourceWidth =
          isPortrait ? previewSize.height : previewSize.width;
          final double sourceHeight =
          isPortrait ? previewSize.width : previewSize.height;

          final double fittedHeight = previewWidth * sourceHeight / sourceWidth;

          if (fittedHeight <= constraints.maxHeight) {
            previewHeight = fittedHeight;
          } else {
            previewHeight = constraints.maxHeight;
            previewWidth = previewHeight * sourceWidth / sourceHeight;
          }
        } else {
          previewHeight = previewWidth / cameraAspectRatio;
          if (previewHeight > constraints.maxHeight) {
            previewHeight = constraints.maxHeight;
            previewWidth = previewHeight * cameraAspectRatio;
          }
        }

        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: previewWidth,
              height: previewHeight,
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(c),
                  const _ScreeningCameraGuideOverlay(),
                  if (_prepareSeconds <= 0)
                    _ScreeningTargetOverlay(exerciseId: currentItem.exerciseId),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _StageBadge(
                      text: '${_screeningIndex() + 1} / ${screeningFunctionItems.length}',
                    ),
                  ),
                  if (_recording)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _StageBadge(
                        text: '$_recordSeconds초',
                        isRecording: true,
                      ),
                    ),
                  if (_prepareSeconds > 0 && !_recording && !_finalizing)
                    Center(
                      child: Container(
                        width: 124,
                        height: 124,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.48),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.72),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$_prepareSeconds',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 50,
                              fontWeight: FontWeight.w900,
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _routeData();

    final int screeningIndex = _screeningIndex();
    final int screeningTotal =
        (data?['screeningTotal'] as int?) ?? screeningFunctionItems.length;
    final currentItem = screeningFunctionItems[screeningIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _cancelEvaluation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('상지 기능 평가'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _cancelEvaluation,
          ),
        ),
        body: _initializing
            ? const Center(child: CircularProgressIndicator())
            : (_controller == null || !_controller!.value.isInitialized)
            ? const Center(child: Text('카메라를 사용할 수 없습니다.'))
            : Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD2E2FA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '평가 ${screeningIndex + 1} / $screeningTotal',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2F67B2),
                          ),
                        ),
                      ),
                      Text(
                        _statusText(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF455468),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    currentItem.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentItem.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5B6676),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _cameraPreviewArea(),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _cancelEvaluation,
                    child: const Text('평가 중단하기'),
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

class _ScreeningCameraGuideOverlay extends StatelessWidget {
  const _ScreeningCameraGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0, -0.20),
            child: Container(
              width: 220,
              height: 2,
              color: Colors.lightGreenAccent.withOpacity(0.82),
            ),
          ),
          Align(
            alignment: const Alignment(-0.82, 0),
            child: Container(
              width: 1.5,
              height: double.infinity,
              color: Colors.white.withOpacity(0.22),
            ),
          ),
          Align(
            alignment: const Alignment(0.82, 0),
            child: Container(
              width: 1.5,
              height: double.infinity,
              color: Colors.white.withOpacity(0.22),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.82),
            child: Container(
              width: double.infinity,
              height: 1.5,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: Colors.white.withOpacity(0.22),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.92),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.50),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '손끝까지 보이게 조금 더 멀리 서 주세요',
                textAlign: TextAlign.center,
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

class _ScreeningTargetOverlay extends StatelessWidget {
  final int exerciseId;

  const _ScreeningTargetOverlay({
    required this.exerciseId,
  });

  _ScreeningCue _cue() {
    switch (exerciseId) {
      case 0:
        return const _ScreeningCue(Offset(0.50, 0.55), Offset(0.50, 0.25), '위로 들어요', false);
      case 1:
        return const _ScreeningCue(Offset(0.50, 0.50), Offset(0.82, 0.36), '옆으로 들어요', false);
      case 2:
        return const _ScreeningCue(Offset(0.50, 0.58), Offset(0.50, 0.30), '머리 쪽으로', true);
      case 3:
        return const _ScreeningCue(Offset(0.50, 0.56), Offset(0.35, 0.66), '허리 뒤로', true);
      case 4:
        return const _ScreeningCue(Offset(0.50, 0.55), Offset(0.50, 0.39), '앞으로 뻗어요', false);
      default:
        return const _ScreeningCue(Offset(0.50, 0.55), Offset(0.50, 0.39), '움직여요', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ScreeningDirectionPainter(_cue()),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ScreeningCue {
  final Offset start;
  final Offset end;
  final String label;
  final bool curved;

  const _ScreeningCue(this.start, this.end, this.label, this.curved);
}

class _ScreeningDirectionPainter extends CustomPainter {
  final _ScreeningCue cue;

  _ScreeningDirectionPainter(this.cue);

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(cue.start.dx * size.width, cue.start.dy * size.height);
    final end = Offset(cue.end.dx * size.width, cue.end.dy * size.height);
    final path = Path()..moveTo(start.dx, start.dy);
    if (cue.curved) {
      path.quadraticBezierTo((start.dx + end.dx) / 2, start.dy - 70, end.dx, end.dy);
    } else {
      path.lineTo(end.dx, end.dy);
    }

    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final paint = Paint()
      ..color = Colors.orangeAccent.withOpacity(0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, shadow);
    canvas.drawPath(path, paint);

    final dir = end - start;
    final angle = dir.direction;
    final p1 = end - Offset.fromDirection(angle - 0.55, 18);
    final p2 = end - Offset.fromDirection(angle + 0.55, 18);
    final arrow = Path()..moveTo(p1.dx, p1.dy)..lineTo(end.dx, end.dy)..lineTo(p2.dx, p2.dy);
    canvas.drawPath(arrow, shadow);
    canvas.drawPath(arrow, paint);
    canvas.drawCircle(end, 6, Paint()..color = Colors.orangeAccent.withOpacity(0.95));

    final tp = TextPainter(
      text: TextSpan(
        text: cue.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = (end.dx - tp.width / 2).clamp(8.0, size.width - tp.width - 8.0);
    final dy = (end.dy + 12).clamp(8.0, size.height - tp.height - 8.0);
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(dx - 8, dy - 4, tp.width + 16, tp.height + 8),
      const Radius.circular(999),
    );
    canvas.drawRRect(bg, Paint()..color = Colors.black.withOpacity(0.45));
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _ScreeningDirectionPainter oldDelegate) => oldDelegate.cue != cue;
}

class _StageBadge extends StatelessWidget {
  final String text;
  final bool isRecording;

  const _StageBadge({
    required this.text,
    this.isRecording = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRecording) ...[
            const Icon(
              Icons.fiber_manual_record,
              color: Colors.redAccent,
              size: 13,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
