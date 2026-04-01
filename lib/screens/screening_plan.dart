import 'package:flutter/material.dart';

class ScreeningFunctionItem {
  final int exerciseId;
  final String functionKey;
  final String title;
  final String desc;
  final String voiceGuide;
  final IconData icon;

  const ScreeningFunctionItem({
    required this.exerciseId,
    required this.functionKey,
    required this.title,
    required this.desc,
    required this.voiceGuide,
    required this.icon,
  });
}

const List<ScreeningFunctionItem> screeningFunctionItems = [
  ScreeningFunctionItem(
    exerciseId: 0,
    functionKey: 'flexion',
    title: '팔 앞으로 들기',
    desc: '팔을 앞으로 천천히 들어보세요.',
    voiceGuide: '팔을 앞으로 천천히 들어보세요.',
    icon: Icons.north,
  ),
  ScreeningFunctionItem(
    exerciseId: 1,
    functionKey: 'abduction',
    title: '팔 옆으로 들기',
    desc: '팔을 옆으로 천천히 들어보세요.',
    voiceGuide: '팔을 옆으로 천천히 들어보세요.',
    icon: Icons.open_in_full,
  ),
  ScreeningFunctionItem(
    exerciseId: 2,
    functionKey: 'hand_to_head',
    title: '머리 만지기',
    desc: '손을 머리 쪽으로 천천히 가져가 보세요.',
    voiceGuide: '손을 머리 쪽으로 천천히 가져가 보세요.',
    icon: Icons.face,
  ),
  ScreeningFunctionItem(
    exerciseId: 3,
    functionKey: 'hand_to_back',
    title: '허리 뒤로 손 가져가기',
    desc: '손을 허리 뒤쪽으로 천천히 가져가 보세요.',
    voiceGuide: '손을 허리 뒤쪽으로 천천히 가져가 보세요.',
    icon: Icons.accessibility_new,
  ),
  ScreeningFunctionItem(
    exerciseId: 4,
    functionKey: 'reach_forward',
    title: '앞으로 손 뻗기',
    desc: '가능한 만큼 손을 앞으로 뻗어보세요.',
    voiceGuide: '가능한 만큼 손을 앞으로 뻗어보세요.',
    icon: Icons.front_hand,
  ),
];

String screeningSummaryText(Map<String, int> scores) {
  if (scores.isEmpty) {
    return '상지 기능 평가 결과를 불러오지 못했습니다.';
  }

  final entries = scores.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));

  final weakest = entries.take(2).map((e) => e.key).toList();

  String label(String key) {
    switch (key) {
      case 'flexion':
        return '팔 앞으로 들기';
      case 'abduction':
        return '팔 옆으로 들기';
      case 'hand_to_head':
        return '머리 만지기';
      case 'hand_to_back':
        return '허리 뒤로 손 가져가기';
      case 'reach_forward':
        return '앞으로 손 뻗기';
      default:
        return key;
    }
  }

  if (weakest.isEmpty) {
    return '현재 상지 기능을 확인했습니다.';
  }

  if (weakest.length == 1) {
    return '현재 상지 기능을 확인했습니다. 특히 ${label(weakest.first)} 동작에서 제한이 보입니다.';
  }

  return '현재 상지 기능을 확인했습니다. 특히 ${label(weakest[0])}, ${label(weakest[1])} 동작에서 제한이 보입니다.';
}

List<int> recommendedExerciseIdsFromScores(Map<String, int> scores) {
  final mapping = <String, int>{
    'flexion': 0,
    'abduction': 1,
    'hand_to_head': 2,
    'hand_to_back': 3,
    'reach_forward': 4,
  };

  final sorted = scores.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));

  return sorted
      .where((e) => mapping.containsKey(e.key))
      .map((e) => mapping[e.key]!)
      .toSet()
      .take(3)
      .toList();
}