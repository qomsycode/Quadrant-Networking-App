class Education {
  final String id;
  final String school;
  final String degree;
  final String fieldOfStudy;
  final DateTime startDate;
  final DateTime? endDate; // Null if currently studying
  final String? description;
  final bool isCurrent;

  Education({
    required this.id,
    required this.school,
    required this.degree,
    required this.fieldOfStudy,
    required this.startDate,
    this.endDate,
    this.description,
    this.isCurrent = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'school': school,
      'degree': degree,
      'fieldOfStudy': fieldOfStudy,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'description': description,
      'isCurrent': isCurrent,
    };
  }

  factory Education.fromMap(Map<String, dynamic> map) {
    return Education(
      id: map['id'] ?? '',
      school: map['school'] ?? '',
      degree: map['degree'] ?? '',
      fieldOfStudy: map['fieldOfStudy'] ?? '',
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'])
          : DateTime.now(),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      description: map['description'],
      isCurrent: map['isCurrent'] ?? false,
    );
  }

  String getDurationString() {
    final end = endDate ?? DateTime.now();
    final duration = end.difference(startDate);
    final years = duration.inDays ~/ 365;
    final months = (duration.inDays % 365) ~/ 30;

    if (years > 0 && months > 0) {
      return '$years yr $months mos'; // Abbreviated for profile validation
    } else if (years > 0) {
      return '$years yr${years > 1 ? 's' : ''}';
    } else if (months > 0) {
      return '$months mo${months > 1 ? 's' : ''}';
    } else {
      return 'Less than a month';
    }
  }
}
