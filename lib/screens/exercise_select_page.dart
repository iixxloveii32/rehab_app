import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../exercises/exercise_definitions.dart';

class ExerciseSelectPage extends StatelessWidget {
  const ExerciseSelectPage({super.key});


  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final data = (extra is Map) ? extra : null;
    final patientId = (data?['patientId'] as int?) ?? -1;

   final items = Exercises.list;

       return Scaffold(
         appBar: AppBar(title: const Text('동작 선택')),
         body: ListView.separated(
           padding: const EdgeInsets.all(16),
           itemCount: items.length,
           separatorBuilder: (_, __) => const SizedBox(height: 10),
           itemBuilder: (context, i) {
             final it = items[i];
             return ListTile(
               tileColor: Colors.grey.shade100,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               title: Text(it.name),
               subtitle: Text(it.desc),
               trailing: const Icon(Icons.chevron_right),
               onTap: () {
                 final sessionUuid = DateTime.now().microsecondsSinceEpoch.toString();

                 final extra = GoRouterState.of(context).extra;
                 final data = (extra is Map) ? extra : null;
                 final affectedSide = (data?['affectedSide'] as String?) ?? 'L';

                 context.push('/record', extra: {
                   'patientId': patientId,
                   'exerciseId': it.id,
                   'sessionUuid': sessionUuid,
                   'affectedSide': affectedSide,
                 });
               },
          );
        },
      ),
    );
  }
}

class _ExerciseItem {
  final int id;
  final String name;
  final String desc;
  const _ExerciseItem(this.id, this.name, this.desc);
}