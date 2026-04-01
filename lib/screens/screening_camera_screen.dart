import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screening_plan.dart';

class ScreeningCameraScreen extends StatefulWidget {
  const ScreeningCameraScreen({super.key});

  @override
  State<ScreeningCameraScreen> createState() => _ScreeningCameraScreenState();
}

class _ScreeningCameraScreenState extends State<ScreeningCameraScreen> {
  CameraController? _controller;

  bool _initializing = true;
  bool _recording = false;
  bool _autoFlowStarted = false;

  XFile? _videoFile;

  int _prepareSeconds = 3;
  int _recordSeconds = 5;

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

  @override
  void dispose() {
    _prepareTimer?.cancel();
    _recordTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _startAutoFlow() {
    if (_autoFlowStarted) return;
    _autoFlowStarted = true;

    _prepareSeconds = 3;
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
        _videoFile = null;
        _recordSeconds = 5;
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
      final file = await c.stopVideoRecording();

      if (!mounted) return;
      setState(() {
        _recording = false;
        _videoFile = file;
      });

      _goAnalyze();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('자동 녹화 종료 실패: $e')),
      );
    }
  }

  void _goAnalyze() {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;

    final int? patientId = data?['patientId'] as int?;
    final String affectedSide = (data?['affectedSide'] as String?) ?? 'L';

    final int screeningIndex = (data?['screeningIndex'] as int?) ?? 0;
    final int screeningTotal =
        (data?['screeningTotal'] as int?) ?? screeningFunctionItems.length;
    final String screeningSessionUuid =
        (data?['screeningSessionUuid'] as String?) ?? '';
    final Map<String, int> screeningScores =
        (data?['screeningScores'] as Map?)
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

  Alignment? _targetAlignment(int exerciseId) {
    switch (exerciseId) {
      case 4:
        return const Alignment(0.0, -0.15);
      default:
        return null;
    }
  }

  Widget _buildTargetOverlay(int exerciseId) {
    final alignment = _targetAlignment(exerciseId);
    if (alignment == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange.withOpacity(0.15),
            border: Border.all(
              color: Colors.orange,
              width: 3,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.pan_tool_alt_outlined,
              color: Colors.orange,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }

  String _statusText() {
    if (_initializing) {
      return '카메라를 준비하고 있습니다.';
    }
    if (_recording) {
      return '지금 동작을 수행해 주세요. $_recordSeconds초 남았어요.';
    }
    if (_prepareSeconds > 0) {
      return '준비해 주세요. $_prepareSeconds초 후 시작합니다.';
    }
    return '영상 확인 중입니다.';
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;

    final int screeningIndex = (data?['screeningIndex'] as int?) ?? 0;
    final int screeningTotal =
        (data?['screeningTotal'] as int?) ?? screeningFunctionItems.length;
    final currentItem = screeningFunctionItems[screeningIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('상지 기능 평가'),
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : (_controller == null || !_controller!.value.isInitialized)
          ? const Center(child: Text('카메라를 사용할 수 없습니다.'))
          : Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '상지 기능 평가 ${screeningIndex + 1} / $screeningTotal',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  currentItem.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentItem.desc,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                _buildTargetOverlay(currentItem.exerciseId),
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
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    context.pop();
                  },
                  child: const Text('평가 중단하기'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}