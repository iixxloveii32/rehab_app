import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'ui/app_scaffold_body.dart';
import 'ui/responsive.dart';
import 'models/patient.dart';
import 'screens/exercise_select_page.dart';
import 'screens/feedback_screen.dart';
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
      color: Colors.black,
      width: double.infinity,
      child: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRect(child: child),
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
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
  bool _autoFlowStarted = false;

  XFile? _videoFile;

  int _prepareSeconds = 3;
  int _recordSeconds = 6;

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
        enableAudio: true,
      );

      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initializing = false;
      });

      await VoiceGuide.speak(
        '건강한 쪽 팔로 천천히 정확하게 움직여 주세요. 몸이 기울어지지 않도록 주의해 주세요.',
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

    await VoiceGuide.speak('준비해 주세요. 3초 후 촬영이 시작됩니다.');

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
        await VoiceGuide.speak('지금 시작합니다.');
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
        _videoFile = null;
        _recordSeconds = 6;
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
      final file = await c.stopVideoRecording();

      if (!mounted) return;
      setState(() {
        _recording = false;
        _videoFile = file;
      });

      _goNext();
    } catch (e) {
      if (!mounted) return;
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
    if (_recording) return '건강한 쪽 팔로 천천히 움직여 주세요. (${_recordSeconds}초)';
    if (_prepareSeconds > 0) return '준비해 주세요. (${_prepareSeconds})';
    return '촬영을 마무리하고 있어요.';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final data = _routeExtra(context);
    final exerciseId = (data?['exerciseId'] as int?) ?? 0;

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
                  StepHeader(
                    step: 1,
                    title: '건강한 쪽 움직임 촬영',
                    subtitle: '건강한 쪽 팔로 ${_exerciseName(exerciseId)} 동작을 천천히 해 주세요.',
                  ),
                  const SizedBox(height: 10),
                  StatusCard(
                    text: _statusText(),
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
                    aspectRatio: _cameraAspectRatioForScreen(context, c),
                    child: CameraPreview(c),
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

  int _playCount = 0;
  final int _targetPlayCount = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      final data = _routeExtra(context);
      final path = data?['videoPath'] as String?;
      if (path == null || path.isEmpty) {
        throw Exception('videoPath가 전달되지 않았습니다.');
      }

      final f = File(path);
      if (!f.existsSync()) {
        throw Exception('영상 파일이 존재하지 않습니다: $path');
      }

      final controller = VideoPlayerController.file(f);

      await controller.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('영상 초기화 시간이 초과되었습니다.'),
      );

      await controller.setLooping(false);
      controller.addListener(_handleVideoProgress);

      if (!mounted) return;
      setState(() {
        _vc = controller;
        _loading = false;
      });

      await VoiceGuide.speak(
        '화면의 동작을 잘 관찰해 주세요. 이 영상은 건강한 쪽 움직임을 좌우반전한 모습입니다.',
      );

      await controller.play();
    } catch (e) {
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

    final position = vc.value.position;
    final duration = vc.value.duration;
    if (duration.inMilliseconds <= 0) return;

    final ended = position.inMilliseconds >= duration.inMilliseconds - 150;
    if (!ended) return;

    if (_playCount < _targetPlayCount - 1) {
      _playCount += 1;
      await vc.seekTo(Duration.zero);
      await vc.play();
      if (mounted) setState(() {});
      return;
    }

    _goImitate();
  }

  Future<void> _cancelExercise() async {
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

    await VoiceGuide.speak('이제 따라하기를 시작합니다.');

    final data = _routeExtra(context);
    final path = data?['videoPath'] as String?;
    final referenceVideoPath =
        data?['referenceVideoPath'] as String? ?? path;

    final patientId = data?['patientId'] as int?;
    final affectedSide = data?['affectedSide'] as String?;
    final exerciseId = data?['exerciseId'] as int?;
    final sessionUuid = data?['sessionUuid'] as String?;

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
    _vc?.removeListener(_handleVideoProgress);
    VoiceGuide.stop();
    _vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = _vc;


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
                    const StepHeader(
                      step: 2,
                      title: '좌우반전 영상 관찰',
                      subtitle: '화면의 동작을 잘 관찰해 주세요. 영상은 2번 반복된 뒤 자동으로 다음 단계로 넘어갑니다.',
                    ),
                    const SizedBox(height: 10),
                    StatusCard(
                      text: '동작을 잘 관찰해 주세요.',
                      trailing: Text(
                        '${_playCount + 1} / $_targetPlayCount',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: vc.value.aspectRatio,
                    child: Transform.flip(
                      flipX: _mirror,
                      child: VideoPlayer(vc),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.maxContentWidth(context),
              ),
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
  int _recordSeconds = 6;

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
    final referenceVideoPath =
        data?['referenceVideoPath'] as String? ?? path;

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

    await VoiceGuide.speak(
      '작은 예시 영상을 참고하면서 환측으로 천천히 따라해 주세요. 준비해 주세요.',
    );

    _prepareSeconds = 3;
    _prepareTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_prepareSeconds <= 1) {
        timer.cancel();
        setState(() => _prepareSeconds = 0);
        await VoiceGuide.speak('지금 따라해 주세요.');
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
        _recordSeconds = 6;
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

    await VoiceGuide.speak('잘하셨습니다. 결과를 확인합니다.');

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
    if (_recording) return '환측으로 천천히 따라해 주세요. (${_recordSeconds}초)';
    if (_prepareSeconds > 0) return '준비해 주세요. (${_prepareSeconds})';
    return '녹화를 마무리하고 있어요.';
  }

  @override
  Widget build(BuildContext context) {
    final vc = _vc;
    final cc = _cc;
    final isTablet = Responsive.isTablet(context);

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
                    const StepHeader(
                      step: 3,
                      title: '환측으로 따라하기',
                      subtitle:
                      '작은 예시 영상을 참고하면서 환측으로 천천히 따라해 주세요.',
                    ),
                    const SizedBox(height: 10),
                    StatusCard(
                      text: _statusText(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _PreviewFrame(
                        aspectRatio:
                        _cameraAspectRatioForScreen(context, cc),
                        child: CameraPreview(cc),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: isTablet ? 180 : 140,
                        height: isTablet ? 280 : 220,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white70),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: vc.value.aspectRatio,
                            child: VideoPlayer(vc),
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
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.maxContentWidth(context),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.horizontalPadding(context),
                  8,
                  Responsive.horizontalPadding(context),
                  16,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _cancelExercise,
                    child: const Text('운동 중단하기'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}