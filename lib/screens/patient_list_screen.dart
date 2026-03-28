import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/patient.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기존 사용자 불러오기'),
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
              ElevatedButton(
                onPressed: () {
                  context.go('/patient-form');
                },
                child: const Text('새 사용자 등록하기'),
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
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.go('/exercise', extra: {
                'patientId': p.id,
                'affectedSide': p.affectedSide ?? 'L',
              });
            },
          );
        },
      ),
    );
  }
}