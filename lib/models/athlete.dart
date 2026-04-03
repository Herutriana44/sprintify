class Athlete {
  Athlete({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    this.className,
  });

  final String id;
  final String name;
  final int age;
  final String gender;
  final String? className;

  Athlete copyWith({
    String? id,
    String? name,
    int? age,
    String? gender,
    String? className,
    bool clearClassName = false,
  }) {
    return Athlete(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      className: clearClassName ? null : (className ?? this.className),
    );
  }
}
