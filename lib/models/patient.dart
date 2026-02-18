class Patient {
  final String name;
  final String sex; // 'M' or 'F'
  final DateTime birthDate;

  const Patient({
    required this.name,
    required this.sex,
    required this.birthDate,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'sex': sex,
    'birthDate': birthDate.toIso8601String(),
  };

  static Patient fromJson(Map<String, dynamic> json) => Patient(
    name: (json['name'] ?? '') as String,
    sex: (json['sex'] ?? 'M') as String,
    birthDate: DateTime.parse(json['birthDate'] as String),
  );
}
