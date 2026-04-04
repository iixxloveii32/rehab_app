import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';

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
        final patientLogs = logs.where((e) => e.patientId == patient.id).toList();
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
        child: _patients.isEmpty ? _emptyView() : _patientList(isTablet),
      ),
      bottomNavigationBar: _patients.isEmpty
          ? null
          : SafeArea(
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
                child: ElevatedButton.icon(
                  onPressed: _goToNewPatient,
                  icon: const Icon(Icons.person_add),
                  label: const Text('새 사용자 등록하기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyView() {
    return Builder(
      builder: (context) => Padding(
        padding: EdgeInsets.all(Responsive.isTablet(context) ? 28 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: Responsive.isTablet(context) ? 84 : 72,
            ),
            const SizedBox(height: 20),
            Text(
              '등록된 사용자가 없습니다',
              style: TextStyle(
                fontSize: Responsive.largeTitleFontSize(context) - 4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '새 사용자를 등록해 주세요',
              style: TextStyle(
                fontSize: Responsive.bodyFontSize(context),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _goToNewPatient,
                child: const Text('새 사용자 등록하기'),
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
        itemCount: _patients.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.7,
        ),
        itemBuilder: (context, index) {
          final p = _patients[index];
          final progress = _progressMap[p.id] ??
              const PatientProgressSummary(
                level: 1,
                totalSessions: 0,
                weeklySessions: 0,
                totalPoints: 0,
                badges: [],
                statusLabel: '시작 전',
                latestFeedback: '첫 운동을 시작해 보세요.',
                completedToday: false,
              );
          return _patientCard(p, progress);
        },
      );
    }

    return ListView.builder(
      itemCount: _patients.length,
      itemBuilder: (context, index) {
        final p = _patients[index];
        final progress = _progressMap[p.id] ??
            const PatientProgressSummary(
              level: 1,
              totalSessions: 0,
              weeklySessions: 0,
              totalPoints: 0,
              badges: [],
              statusLabel: '시작 전',
              latestFeedback: '첫 운동을 시작해 보세요.',
              completedToday: false,
            );

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _patientCard(p, progress),
        );
      },
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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