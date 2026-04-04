import '../models/session_log.dart';

class PatientProgressSummary {
  final int level;
  final int totalSessions;
  final int weeklySessions;
  final int totalPoints;
  final List<String> badges;
  final String statusLabel;
  final String latestFeedback;
  final bool completedToday;

  const PatientProgressSummary({
    required this.level,
    required this.totalSessions,
    required this.weeklySessions,
    required this.totalPoints,
    required this.badges,
    required this.statusLabel,
    required this.latestFeedback,
    required this.completedToday,
  });
}

class PatientProgressHelper {
  static PatientProgressSummary fromLogs(List<SessionLog> logs) {
    final imitLogs = logs.where((e) => e.isReference == false).toList()
      ..sort((a, b) => b.timestampKst.compareTo(a.timestampKst));

    if (imitLogs.isEmpty) {
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

    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final weekAgo = now.subtract(const Duration(days: 7));

    final todayLogs = imitLogs.where((e) => e.dateKey == todayKey).toList();
    final weeklyLogs =
    imitLogs.where((e) => e.timestampKst.isAfter(weekAgo)).toList();

    final sessionSet = <String>{};
    for (final log in imitLogs) {
      if (log.sessionUuid.isNotEmpty) {
        sessionSet.add(log.sessionUuid);
      }
    }

    final weeklySessionSet = <String>{};
    for (final log in weeklyLogs) {
      if (log.sessionUuid.isNotEmpty) {
        weeklySessionSet.add(log.sessionUuid);
      }
    }

    final totalSessions = sessionSet.length;
    final weeklySessions = weeklySessionSet.length;
    final totalPoints = _calculatePoints(imitLogs);
    final level = _calculateLevel(totalPoints);
    final badges = _buildBadges(imitLogs, totalSessions, weeklySessions);
    final latestFeedback = _buildLatestFeedback(imitLogs);
    final completedToday = todayLogs.isNotEmpty;
    final statusLabel = completedToday ? '오늘 완료' : '오늘 미완료';

    return PatientProgressSummary(
      level: level,
      totalSessions: totalSessions,
      weeklySessions: weeklySessions,
      totalPoints: totalPoints,
      badges: badges,
      statusLabel: statusLabel,
      latestFeedback: latestFeedback,
      completedToday: completedToday,
    );
  }

  static int _calculatePoints(List<SessionLog> logs) {
    int points = 0;
    for (final log in logs) {
      points += (log.overall / 10).round();
    }
    return points;
  }

  static int _calculateLevel(int points) {
    if (points >= 120) return 6;
    if (points >= 80) return 5;
    if (points >= 50) return 4;
    if (points >= 25) return 3;
    if (points >= 10) return 2;
    return 1;
  }

  static List<String> _buildBadges(
      List<SessionLog> logs,
      int totalSessions,
      int weeklySessions,
      ) {
    final badges = <String>[];

    final bestOverall =
    logs.map((e) => e.overall).fold<int>(0, (a, b) => a > b ? a : b);

    final avgSmoothness =
        logs.map((e) => e.smoothness).reduce((a, b) => a + b) / logs.length;

    final avgSymmetry =
        logs.map((e) => e.symmetry).reduce((a, b) => a + b) / logs.length;

    final avgCompensation =
        logs.map((e) => e.compensation).reduce((a, b) => a + b) / logs.length;

    if (totalSessions >= 1) badges.add('첫 완료');
    if (weeklySessions >= 3) badges.add('꾸준함');
    if (totalSessions >= 10) badges.add('성실함');
    if (bestOverall >= 85) badges.add('고득점');
    if (avgSmoothness >= 70) badges.add('부드러움');
    if (avgSymmetry >= 70) badges.add('균형');
    if (avgCompensation >= 70) badges.add('안정성');

    return badges;
  }

  static String _buildLatestFeedback(List<SessionLog> logs) {
    if (logs.isEmpty) return '첫 운동을 시작해 보세요.';
    if (logs.length == 1) return '첫 기록이 저장되었어요. 계속 이어가 보세요.';

    final latest = logs[0];
    final previous = logs[1];

    if (latest.overall > previous.overall + 5) {
      return '지난번보다 전체 수행이 좋아졌어요.';
    }
    if (latest.smoothness > previous.smoothness + 5) {
      return '움직임이 조금 더 부드러워졌어요.';
    }
    if (latest.symmetry > previous.symmetry + 5) {
      return '좌우 균형이 좋아지고 있어요.';
    }
    if (latest.compensation > previous.compensation + 5) {
      return '몸통 안정성이 좋아지고 있어요.';
    }
    if (latest.rom > previous.rom + 5) {
      return '움직임의 범위가 더 좋아졌어요.';
    }
    return '꾸준히 잘 이어가고 있어요.';
  }

  static String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}