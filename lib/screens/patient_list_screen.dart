import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../helpers/patient_progress_helper.dart';
import '../models/patient.dart';
import '../models/session_log.dart';
import '../storage/isar_db.dart';
import '../ui/app_scaffold_body.dart';
import '../ui/responsive.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  bool _loading = true;
  String? _error;
  List<Patient> _patients = [];
  Map<int, PatientProgressSummary> _progressMap = {};

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    try {
      final isar = IsarDB.instance;

      final patients = await isar.patients.where().findAll();
      final logs = await isar.sessionLogs.where().findAll();

      final progressMap = <int, PatientProgressSummary>{};

      for (final patient in patients) {
        final patientLogs =
        logs.where((e) => e.patientId == patient.id).toList();
        progressMap[patient.id] = PatientProgressHelper.fromLogs(patientLogs);
      }

      patients.sort((a, b) => b.id.compareTo(a.id));

      if (!mounted) return;
      setState(() {
        _patients = patients;
        _progressMap = progressMap;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }


  String _csvEscape(dynamic value) {
    final text = (value ?? '').toString();
    final escaped = text.replaceAll('"', '""');

    if (escaped.contains(',') ||
        escaped.contains('\n') ||
        escaped.contains('\r') ||
        escaped.contains('"')) {
      return '"$escaped"';
    }

    return escaped;
  }

  String _dateTimeLabel(DateTime? dt) {
    if (dt == null) return '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }

  String _dateOnlyLabel(DateTime? dt) {
    if (dt == null) return '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _safeFileName(String value) {
    return value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_')
        .trim();
  }

  Future<void> _exportPatientCsv(Patient patient) async {
    try {
      final isar = IsarDB.instance;

      final logs = await isar.sessionLogs
          .filter()
          .patientIdEqualTo(patient.id)
          .findAll();

      logs.sort((a, b) => a.timestampKst.compareTo(b.timestampKst));

      if (logs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${patient.name}님의 저장된 운동 기록이 없습니다.'),
          ),
        );
        return;
      }

      final headers = <String>[
        'patientId',
        'patientName',
        'sex',
        'birthDate',
        'affectedSide',
        'logId',
        'sessionUuid',
        'dateKey',
        'timestampKst',
        'exerciseId',
        'exerciseName',
        'isReference',
        'attemptIndex',
        'overall',
        'symmetry',
        'timing',
        'smoothness',
        'compensation',
        'rom',
        'appVersion',
        'scoreSchemaVersion',
        'referenceVideoPath',
        'imitationVideoPath',
        'qualityJson',
        'featuresJson',
      ];

      final rows = <List<dynamic>>[
        headers,
        ...logs.map(
              (log) => <dynamic>[
            patient.id,
            patient.name,
            _sexLabel(patient.sex),
            _dateOnlyLabel(patient.birthDate),
            _sideLabel(patient.affectedSide),
            log.id,
            log.sessionUuid,
            log.dateKey,
            _dateTimeLabel(log.timestampKst),
            log.exerciseId,
            _exerciseNameForCsv(log.exerciseId),
            log.isReference ? 'reference' : 'imitation',
            log.attemptIndex,
            log.overall,
            log.symmetry,
            log.timing,
            log.smoothness,
            log.compensation,
            log.rom,
            log.appVersion,
            log.scoreSchemaVersion,
            log.referenceVideoPath ?? '',
            log.imitationVideoPath ?? '',
            log.qualityJson ?? '',
            log.featuresJson ?? '',
          ],
        ),
      ];

      final csv = rows
          .map((row) => row.map(_csvEscape).join(','))
          .join('\r\n');

      // Excel 한글 깨짐 방지용 UTF-8 BOM
      final csvWithBom = '\uFEFF$csv';

      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final datePart =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final fileName =
          'rehab_${_safeFileName(patient.name)}_${patient.id}_$datePart.csv';
      final file = File('${dir.path}/$fileName');

      await file.writeAsString(csvWithBom, encoding: utf8);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${patient.name} 재활 운동 기록 CSV',
        text: '${patient.name}님의 재활 운동 기록 CSV 파일입니다.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV 내보내기 실패: $e')),
      );
    }
  }

  String _exerciseNameForCsv(int id) {
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

  Future<void> _confirmDeletePatient(Patient patient) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용자 삭제'),
        content: Text(
          '${patient.name}님의 정보를 삭제하시겠습니까?\n운동 기록도 함께 삭제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _deletePatient(patient.id);
    }
  }

  Future<void> _deletePatient(int patientId) async {
    try {
      final isar = IsarDB.instance;

      await isar.writeTxn(() async {
        final logs = await isar.sessionLogs
            .filter()
            .patientIdEqualTo(patientId)
            .findAll();

        final logIds = logs.map((e) => e.id).toList();
        if (logIds.isNotEmpty) {
          await isar.sessionLogs.deleteAll(logIds);
        }

        await isar.patients.delete(patientId);
      });

      await _loadPatients();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자가 삭제되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  String _sexLabel(String? sex) {
    if (sex == 'M') return '남';
    if (sex == 'F') return '여';
    return '-';
  }

  String _sideLabel(String? side) {
    if (side == 'L') return '좌측';
    if (side == 'R') return '우측';
    return '-';
  }

  String _birthLabel(DateTime? birthDate) {
    if (birthDate == null) return '-';
    return '${birthDate.year}.${birthDate.month}.${birthDate.day}';
  }

  void _goToNewPatient() {
    context.go('/patient-form');
  }

  void _selectPatient(Patient p) {
    context.go('/exercise', extra: {
      'patientId': p.id,
      'affectedSide': p.affectedSide,
    });
  }

  Color _statusColor(bool completedToday) {
    return completedToday
        ? const Color(0xFFEAF7EE)
        : const Color(0xFFFFF3E8);
  }

  Color _statusTextColor(bool completedToday) {
    return completedToday
        ? const Color(0xFF3FAE6F)
        : const Color(0xFFE0A63E);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 선택'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : _loadPatients,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '오류: $_error',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      )
          : AppScaffoldBody(
        child: Column(
          children: [
            Expanded(
              child: _patients.isEmpty
                  ? _emptyView()
                  : _patientList(isTablet),
            ),
            const SizedBox(height: 12),
            SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _goToNewPatient,
                  icon: const Icon(Icons.person_add),
                  label: const Text('새 사용자 등록하기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Responsive.isTablet(context) ? 28 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              size: Responsive.isTablet(context) ? 84 : 72,
              color: const Color(0xFF8A96A8),
            ),
            const SizedBox(height: 20),
            Text(
              '등록된 사용자가 없습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Responsive.largeTitleFontSize(context) - 4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '새 사용자를 등록한 뒤 재활 운동을 시작할 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Responsive.bodyFontSize(context),
                color: const Color(0xFF5B6676),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patientList(bool isTablet) {
    if (isTablet) {
      return GridView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: _patients.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.7,
        ),
        itemBuilder: (context, index) {
          final p = _patients[index];
          final progress = _progressMap[p.id] ?? _defaultProgress();
          return _patientCard(p, progress);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: _patients.length,
      itemBuilder: (context, index) {
        final p = _patients[index];
        final progress = _progressMap[p.id] ?? _defaultProgress();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _patientCard(p, progress),
        );
      },
    );
  }

  PatientProgressSummary _defaultProgress() {
    return const PatientProgressSummary(
      level: 1,
      totalSessions: 0,
      weeklySessions: 0,
      totalPoints: 0,
      badges: [],
      statusLabel: '시작 전',
      latestFeedback: '첫 운동을 시작해 보세요.',
      completedToday: false,
    );
  }

  Widget _patientCard(Patient p, PatientProgressSummary progress) {
    final badges = progress.badges.take(3).toList();
    final extraBadgeCount =
    progress.badges.length > 3 ? progress.badges.length - 3 : 0;

    return InkWell(
      onTap: () => _selectPatient(p),
      borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
      child: Container(
        padding: EdgeInsets.all(Responsive.isTablet(context) ? 20 : 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Responsive.cardRadius(context)),
          border: Border.all(color: const Color(0xFFE3E8EF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    style: TextStyle(
                      fontSize: Responsive.bodyFontSize(context) + 3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Lv.${progress.level}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF5B8DEF),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDeletePatient(p),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_sexLabel(p.sex)} / ${_birthLabel(p.birthDate)} / 환측 ${_sideLabel(p.affectedSide)}',
              style: TextStyle(
                fontSize: Responsive.bodyFontSize(context) - 1,
                color: const Color(0xFF5B6676),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(progress.completedToday),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    progress.statusLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _statusTextColor(progress.completedToday),
                    ),
                  ),
                ),
                _smallInfoChip('이번 주 ${progress.weeklySessions}회'),
                _smallInfoChip('총 ${progress.totalSessions}회'),
                _smallInfoChip('${progress.totalPoints}P'),
              ],
            ),
            const SizedBox(height: 12),
            if (badges.isNotEmpty) ...[
              Text(
                '대표 보상',
                style: TextStyle(
                  fontSize: Responsive.bodyFontSize(context) - 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...badges.map(
                        (badge) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '🎖 $badge',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (extraBadgeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F4F8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+$extraBadgeCount',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                progress.latestFeedback,
                style: TextStyle(
                  fontSize: Responsive.bodyFontSize(context) - 1,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF455468),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _exportPatientCsv(p),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('CSV 내보내기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}