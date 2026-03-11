String sideText(String side) {
  return side == 'L' ? '왼팔' : '오른팔';
}

String recordInstruction(String affectedSide, String exerciseName) {
  final recordSide = affectedSide == 'L' ? 'R' : 'L';
  return '${sideText(recordSide)}로 $exerciseName 를 해주세요';
}

String imitationInstruction(String affectedSide, String exerciseName) {
  return '${sideText(affectedSide)}로 $exerciseName 를 따라 해주세요';
}