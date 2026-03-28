import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StartMenuScreen extends StatelessWidget {
  const StartMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('상지 재활 앱'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Icon(Icons.accessibility_new, size: 56),
                  SizedBox(height: 12),
                  Text(
                    '상지 재활 운동 시작',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '새 사용자를 등록하거나\n이전 사용자를 불러와 운동을 시작할 수 있어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  context.go('/patient-form');
                },
                child: const Text('새 사용자 등록'),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () {
                  context.go('/patient-list');
                },
                child: const Text('기존 사용자 불러오기'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}