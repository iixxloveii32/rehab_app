import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  Map<int, _PatientSummary> _summaryMap = {};

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

      final summaryMap = <int, _PatientSummary>{};
      for (final patient in patients) {
        final patientLogs = logs
            .where((e) => e.patientId == patient.id && e.isReference == false)
            .toList();
        summaryMap[patient.id] = _PatientSummary.fromLogs(patientLogs);
      }

      patients.sort((a, b) => b.id.compareTo(a.id));

      if (!mounted) return;
      setState(() {
        _patients = patients;
        _summaryMap = summaryMap;
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
          SnackBar(content: Text('${patient.name}님의 저장된 운동 기록이 없습니다.')),
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
            _exerciseName(log.exerciseId),
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

      final csv = rows.map((row) => row.map(_csvEscape).join(',')).join('\r\n');
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

  void _goToNewPatient() {
    context.go('/patient-form');
  }

  void _selectPatient(Patient patient) {
    context.go('/exercise', extra: {
      'patientId': patient.id,
      'affectedSide': patient.affectedSide,
    });
  }

  void _goHistory(Patient patient) {
    context.go('/exercise-history', extra: {
      'patientId': patient.id,
      'affectedSide': patient.affectedSide,
    });
  }

  Color _statusColor(bool completedToday) {
    return completedToday ? const Color(0xFFEAF7EE) : const Color(0xFFFFF3E8);
  }

  Color _statusTextColor(bool completedToday) {
    return completedToday ? const Color(0xFF3FAE6F) : const Color(0xFFE0A63E);
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
            const Text(
              '새 사용자를 등록한 뒤 재활 운동을 시작할 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.45,
                color: Color(0xFF5B6676),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _goToNewPatient,
                icon: const Icon(Icons.person_add),
                label: const Text('새 사용자 등록하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patientList(bool isTablet) {
    return RefreshIndicator(
      onRefresh: _loadPatients,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: 16 + MediaQuery.of(context).padding.bottom,
        ),
        itemBuilder: (context, index) {
          final patient = _patients[index];
          return _patientCard(patient, isTablet);
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: _patients.length,
      ),
    );
  }

  Widget _patientCard(Patient patient, bool isTablet) {
    final summary = _summaryMap[patient.id] ?? _PatientSummary.empty();

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE6F2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: isTablet ? 30 : 26,
                backgroundColor: const Color(0xFFEAF2FF),
                child: Text(
                  patient.name.isEmpty ? '?' : patient.name.characters.first,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2F67B2),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: TextStyle(
                        fontSize: isTablet ? 24 : 21,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_sexLabel(patient.sex)} · ${_birthLabel(patient.birthDate)} · 환측 ${_sideLabel(patient.affectedSide)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5B6676),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '삭제',
                onPressed: () => _confirmDeletePatient(patient),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statusChip(summary.completedToday),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary.lastDateLabel == '-'
                      ? '아직 저장된 운동기록이 없습니다.'
                      : '최근 운동일: ${summary.lastDateLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5B6676),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryBox(
                  label: '운동일수',
                  value: '${summary.totalDays}일',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryBox(
                  label: '완료운동',
                  value: '${summary.totalExercises}개',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryBox(
                  label: '평균점수',
                  value: '${summary.averageScore}점',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _selectPatient(patient),
              icon: const Icon(Icons.play_arrow),
              label: const Text('오늘 운동 시작'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _goHistory(patient),
                  icon: const Icon(Icons.history),
                  label: const Text('운동기록'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportPatientCsv(patient),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('CSV 내보내기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(bool completedToday) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(completedToday),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        completedToday ? '오늘 완료' : '오늘 미완료',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: _statusTextColor(completedToday),
        ),
      ),
    );
  }

  Widget _summaryBox({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8EF)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5B6676),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F2A37),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientSummary {
  final int totalDays;
  final int totalExercises;
  final int averageScore;
  final String lastDateLabel;
  final bool completedToday;

  const _PatientSummary({
    required this.totalDays,
    required this.totalExercises,
    required this.averageScore,
    required this.lastDateLabel,
    required this.completedToday,
  });

  factory _PatientSummary.empty() {
    return const _PatientSummary(
      totalDays: 0,
      totalExercises: 0,
      averageScore: 0,
      lastDateLabel: '-',
      completedToday: false,
    );
  }

  factory _PatientSummary.fromLogs(List<SessionLog> logs) {
    if (logs.isEmpty) return _PatientSummary.empty();

    logs.sort((a, b) => a.timestampKst.compareTo(b.timestampKst));
    final days = logs.map((e) => e.dateKey).toSet();
    final avg = (logs.map((e) => e.overall).reduce((a, b) => a + b) /
        logs.length)
        .round();
    final last = logs.last.timestampKst;
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return _PatientSummary(
      totalDays: days.length,
      totalExercises: logs.length,
      averageScore: avg,
      lastDateLabel:
      '${last.year}-${last.month.toString().padLeft(2, '0')}-${last.day.toString().padLeft(2, '0')}',
      completedToday: logs.any((e) => e.dateKey == todayKey),
    );
  }
}
