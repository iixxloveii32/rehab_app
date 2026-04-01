import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';

import '../models/patient.dart';
import '../models/session_log.dart';
import '../storage/isar_db.dart';
import '../storage/patient_store.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  bool _loading = true;
  String? _error;
  List<Patient> _patients = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    try {
      final patients = await PatientStore.getAllPatients();

      if (!mounted) return;
      setState(() {
        _patients = patients;
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
        title: const Text('환자 삭제'),
        content: Text(
          '${patient.name} 환자 정보를 삭제하시겠습니까?\n운동 기록도 함께 삭제됩니다.',
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
        const SnackBar(content: Text('환자 정보가 삭제되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  String _sexLabel(String? sex) {
    if (sex == null || sex.isEmpty) return '-';
    if (sex == 'M') return '남';
    if (sex == 'F') return '여';
    return sex;
  }

  String _sideLabel(String? side) {
    if (side == null || side.isEmpty) return '-';
    return side == 'L' ? '좌측' : '우측';
  }

  String _birthLabel(DateTime? birthDate) {
    if (birthDate == null) return '-';
    final y = birthDate.year.toString().padLeft(4, '0');
    final m = birthDate.month.toString().padLeft(2, '0');
    final d = birthDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 선택'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: '새 사용자 등록',
            onPressed: _goToNewPatient,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('오류: $_error'),
        ),
      )
          : _patients.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '저장된 사용자가 없습니다.',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _goToNewPatient,
                  child: const Text('새 사용자 등록하기'),
                ),
              ),
            ],
          ),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _patients.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final p = _patients[index];

          return ListTile(
            tileColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: Text(
              p.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '성별: ${_sexLabel(p.sex)}   '
                    '생년월일: ${_birthLabel(p.birthDate)}   '
                    '환측: ${_sideLabel(p.affectedSide)}',
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  tooltip: '삭제',
                  onPressed: () => _confirmDeletePatient(p),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _selectPatient(p),
          );
        },
      ),
      bottomNavigationBar: _patients.isEmpty
          ? null
          : SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _goToNewPatient,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('새 사용자 등록하기'),
            ),
          ),
        ),
      ),
    );
  }
}