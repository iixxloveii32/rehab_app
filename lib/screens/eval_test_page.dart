import 'package:flutter/material.dart';

import '../models/evaluation.dart';
import '../storage/isar_db.dart';
import 'package:isar/isar.dart';

class EvalTestPage extends StatefulWidget {
  const EvalTestPage({super.key});

  @override
  State<EvalTestPage> createState() => _EvalTestPageState();
}

class _EvalTestPageState extends State<EvalTestPage> {
  List<Evaluation> items = [];
  bool loading = false;

  Future<void> _reload() async {
    setState(() => loading = true);
    final isar = IsarDB.instance;

    final data = await isar.evaluations.where().sortByDateDesc().findAll();

    setState(() {
      items = data;
      loading = false;
    });
  }

  Future<void> _addSample() async {
    final isar = IsarDB.instance;

    final e = Evaluation()
      ..patientName = '홍길동'
      ..date = DateTime.now()
      ..rolling = 5
      ..comeToSit = 4
      ..sitToStand = 4
      ..transfer = 3
      ..gait = 2
      ..stair = 1;

    await isar.writeTxn(() async {
      await isar.evaluations.put(e);
    });

    await _reload();
  }

  Future<void> _clearAll() async {
    final isar = IsarDB.instance;

    await isar.writeTxn(() async {
      await isar.evaluations.clear();
    });

    await _reload();
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evaluation DB Test'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? const Center(child: Text('No data yet'))
          : ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final e = items[i];
          return ListTile(
            title: Text('${e.patientName}  |  ${e.totalScore}점'),
            subtitle: Text(e.date.toIso8601String()),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: _addSample,
            label: const Text('샘플 저장'),
            icon: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'clear',
            onPressed: items.isEmpty ? null : _clearAll,
            label: const Text('전체 삭제'),
            icon: const Icon(Icons.delete),
          ),
        ],
      ),
    );
  }
}