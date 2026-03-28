import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScreeningCameraScreen extends StatefulWidget {
  const ScreeningCameraScreen({super.key});

  @override
  State<ScreeningCameraScreen> createState() => _ScreeningCameraScreenState();
}

class _ScreeningCameraScreenState extends State<ScreeningCameraScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _recording = false;
  XFile? _videoFile;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front);
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
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    try {
      if (_recording) {
        final file = await c.stopVideoRecording();
        if (!mounted) return;
        setState(() {
          _recording = false;
          _videoFile = file;
        });
      } else {
        await c.prepareForVideoRecording();
        await c.startVideoRecording();
        if (!mounted) return;
        setState(() {
          _recording = true;
          _videoFile = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('녹화 오류: $e')),
      );
    }
  }

  void _goAnalyze() {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;

    final path = _videoFile?.path;
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 녹화를 완료해 주세요.')),
      );
      return;
    }

    context.push('/screening-analyze', extra: {
      ...?data,
      'videoPath': path,
    });
  }

  Alignment? _targetAlignment(int exerciseId) {
    switch (exerciseId) {
      case 4:
        return const Alignment(0.0, -0.15); // 앞으로 손 뻗기: 중앙 앞쪽
      case 5:
        return const Alignment(0.65, 0.0); // 옆으로 손 뻗기: 오른쪽 옆
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

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;
    final title = (data?['title'] as String?) ?? '평가 동작';
    final desc = (data?['desc'] as String?) ?? '';
    final exerciseId = (data?['exerciseId'] as int?) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('현재 상태 촬영')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : (_controller == null || !_controller!.value.isInitialized)
          ? const Center(child: Text('카메라를 사용할 수 없습니다.'))
          : Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                _buildTargetOverlay(exerciseId),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _toggleRecord,
                        child: Text(_recording ? '녹화 중지' : '녹화 시작'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _recording ? null : _goAnalyze,
                        child: const Text('분석하기'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}