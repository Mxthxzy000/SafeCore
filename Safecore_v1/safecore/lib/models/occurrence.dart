import 'enums.dart';

class Occurrence {
  const Occurrence({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.reportedByName,
    required this.createdAt,
    this.reportedBy,
    this.areaId,
    this.areaName,
    this.responsibleName,
  });

  final String id;
  final OccurrenceKind kind;
  final String title;
  final String description;
  final Priority priority;
  final OccurrenceStatus status;
  final String? reportedBy;
  final String reportedByName;
  final String? responsibleName;
  final String? areaId;
  final String? areaName;
  final DateTime createdAt;

  factory Occurrence.fromMap(Map<String, dynamic> map) {
    final area = map['areas'];
    return Occurrence(
      id: map['id'] as String,
      kind: OccurrenceKind.parse(map['kind'] as String?),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      priority: Priority.parse(map['priority'] as String?),
      status: OccurrenceStatus.parse(map['status'] as String?),
      reportedBy: map['reported_by'] as String?,
      reportedByName: map['reported_by_name'] as String? ?? '',
      responsibleName: map['responsible_name'] as String?,
      areaId: map['area_id'] as String?,
      areaName: area is Map ? area['name'] as String? : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
