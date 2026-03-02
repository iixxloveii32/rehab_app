import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'models/patient.dart';
import 'storage/patient_store.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'dart:math' as math;
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart';
import 'screens/feedback_screen.dart';
import 'screens/results_page.dart';
import 'screens/exercise_select_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const PatientFormScreen(),
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

  ],
);


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
      if (mounted) setState(() => _saving = false);
    }
  }

  String _birthLabel() {
    if (_birthDate == null) return '생년월일 선택';
    final d = _birthDate!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day
        .toString()
        .padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('환자 정보 입력')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: '이름',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return '이름을 입력해 주세요.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

// ---- 성별 ----
                          Row(
                            children: [
                              const Text('성별: '),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('남'),
                                selected: _sex == 'M',
                                onSelected: (_) => setState(() => _sex = 'M'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('여'),
                                selected: _sex == 'F',
                                onSelected: (_) => setState(() => _sex = 'F'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

// ---- 환측 ----
                          Row(
                            children: [
                              const Text('환측: '),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('좌'),
                                selected: _affectedSide == 'L',
                                onSelected: (_) => setState(() => _affectedSide = 'L'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('우'),
                                selected: _affectedSide == 'R',
                                onSelected: (_) => setState(() => _affectedSide = 'R'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _pickBirthDate,
                              child: Text(_birthLabel()),
                            ),
                          ),
                          const Spacer(),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _onNext,
                              child: Text(_saving ? '저장 중...' : '다음'),
                            ),
                          ),

                          const SizedBox(height: 24),
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
  XFile? _videoFile;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      // 전면 카메라 우선
      final front =
      cameras.where((c) => c.lensDirection == CameraLensDirection.front);
      final selected = front.isNotEmpty ? front.first : cameras.first;

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: true,
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

  void _goNext() {
    final path = _videoFile?.path;
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 녹화를 완료해 주세요.')),
      );
      return;
    }

    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;

    final patientId = data?['patientId'] as int?;
    final exerciseId = data?['exerciseId'] as int?;
    final sessionUuid = data?['sessionUuid'] as String?;

    context.go('/review', extra: {
      'videoPath': path,
      'patientId': patientId,
      'exerciseId': exerciseId,
      'sessionUuid': sessionUuid,
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    return Scaffold(
      appBar: AppBar(title: const Text('촬영 화면')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : (c == null || !c.value.isInitialized)
          ? const Center(child: Text('카메라를 사용할 수 없습니다.'))
          : Column(
        children: [
          Expanded(child: CameraPreview(c)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _toggleRecord,
                    child: Text(_recording ? '녹화 중지' : '녹화 시작'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _recording ? null : _goNext,
                    child: const Text('다음(관찰)'),
                  ),
                ),
              ],
            ),
          ),
        ],
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
  bool _mirror = true; // 좌우반전 기본 ON

  @override
  void initState() {
    super.initState();
    // extra는 build에서만 접근 가능해서, 첫 프레임 후에 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      final extra = GoRouterState.of(context).extra;
      final data = (extra is Map) ? extra : null;

      final path = data?['videoPath'] as String?;
      if (path == null || path.isEmpty) {
        throw Exception('videoPath가 전달되지 않았습니다.');
      }
      final f = File(path);
      if (!f.existsSync()) {
        throw Exception('영상 파일이 존재하지 않습니다: $path');
      }

      final controller = VideoPlayerController.file(f);

      // ✅ 무한 로딩 방지: 10초 타임아웃
      await controller.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('영상 초기화 시간이 초과되었습니다(10초).'),
      );

      await controller.setLooping(true);
      await controller.play();

      if (!mounted) return;
      setState(() {
        _vc = controller;
        _loading = false;
      });
    } catch (e) {
      // ✅ 어떤 경우든 로딩 종료 + 원인 표시
      debugPrint('ReviewScreen init error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('관찰 영상 로드 실패: $e')),
      );
    }
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = _vc;

    return Scaffold(
      appBar: AppBar(
        title: const Text('관찰 화면'),
        actions: [
          Row(
            children: [
              const Text('좌우반전'),
              Switch(
                value: _mirror,
                onChanged: (v) => setState(() => _mirror = v),
              ),
              const SizedBox(width: 8),
            ],
          )
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (vc == null || !vc.value.isInitialized)
          ? const Center(child: Text('영상을 불러오지 못했습니다.'))
          : Center(
        child: AspectRatio(
          aspectRatio: vc.value.aspectRatio,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateY(_mirror ? math.pi : 0),
            child: VideoPlayer(vc),
          ),
        ),
      ),

      floatingActionButton: (vc == null)
          ? null
          : FloatingActionButton(
        onPressed: () {
          setState(() {
            vc.value.isPlaying ? vc.pause() : vc.play();
          });
        },
        child: Icon(
          vc.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final extra = GoRouterState.of(context).extra;
                final data = (extra is Map) ? extra : null;

                final path = data?['videoPath'] as String?;
                final patientId = data?['patientId'] as int?;

                if (path == null) return;

                final exerciseId = data?['exerciseId'] as int?;
                final sessionUuid = data?['sessionUuid'] as String?;
                context.go('/imitate', extra: {
                  'videoPath': path,
                  'patientId': patientId,
                  'exerciseId': exerciseId,
                  'sessionUuid': sessionUuid,
                });
              },
              child: const Text('따라하기(2분할)로'),
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
  bool _mirror = true;
  bool _recording = false;
  XFile? _patientVideo;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }
  @override
  void dispose() {
    _vc?.dispose();
    _cc?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;

    final path = data?['videoPath'] as String?;
    final patientId = data?['patientId'] as int?;
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영상 경로가 없습니다.')),
      );
      return;
    }

    try {
      // 1) 비디오
      final vc = VideoPlayerController.file(File(path));
      await vc.initialize();
      await vc.setLooping(true);
      await vc.play();

      // 2) 카메라(전면)
      final cameras = await availableCameras();
      final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front);
      final selected = front.isNotEmpty ? front.first : cameras.first;

      final cc = CameraController(selected, ResolutionPreset.medium, enableAudio: false);
      await cc.initialize();

      if (!mounted) return;
      setState(() {
        _vc = vc;
        _cc = cc;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('초기화 실패: $e')),
      );
    }
  }
  Future<void> _togglePatientRecord() async {
    final cc = _cc;
    if (cc == null || !cc.value.isInitialized) return;

    try {
      if (_recording) {
        final file = await cc.stopVideoRecording();
        if (!mounted) return;
        setState(() {
          _recording = false;
          _patientVideo = file;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('환자 영상 저장됨: ${file.path}')),
        );
      } else {
        await cc.prepareForVideoRecording();
        await cc.startVideoRecording();
        if (!mounted) return;
        setState(() {
          _recording = true;
          _patientVideo = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('환자 녹화 오류: $e')),
      );
    }
  }

  void _goFeedback() {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;

    final modelPath = data?['videoPath'] as String?;
    final patientId = data?['patientId'] as int?;

    final patientPath = _patientVideo?.path;

    if (modelPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모델(관찰) 영상 경로가 없습니다.')),
      );
      return;
    }
    if (patientPath == null || patientPath.isEmpty || !File(patientPath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('환자 녹화를 먼저 완료해 주세요.')),
      );
      return;
    }

    final exerciseId = data?['exerciseId'] as int?;
    final sessionUuid = data?['sessionUuid'] as String?;

    context.go('/feedback', extra: {
      'modelPath': modelPath,
      'patientPath': patientPath,
      'patientId': patientId,
      'exerciseId': exerciseId,
      'sessionUuid': sessionUuid,
    });
  }

  @override
  Widget build(BuildContext context) {
    final vc = _vc;
    final cc = _cc;

    return Scaffold(
      appBar: AppBar(
        title: const Text('따라하기(2분할)'),
        actions: [
          Row(
            children: [
              const Text('영상 반전'),
              Switch(value: _mirror, onChanged: (v) => setState(() => _mirror = v)),
              const SizedBox(width: 8),
            ],
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (vc == null || cc == null)
          ? const Center(child: Text('화면을 불러오지 못했습니다.'))
          : Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // 관찰 영상
                Expanded(
                  child: AspectRatio(
                    aspectRatio: vc.value.aspectRatio,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(_mirror ? math.pi : 0),
                      child: VideoPlayer(vc),
                    ),
                  ),
                ),
                // 셀카 프리뷰
                Expanded(
                  child: CameraPreview(cc),
                ),
              ],
            ),
          ),
        ],
      ),

    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _togglePatientRecord,
                child: Text(_recording ? '환자 녹화 중지' : '환자 녹화 시작'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _recording ? null : _goFeedback,
                child: const Text('피드백으로'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}


