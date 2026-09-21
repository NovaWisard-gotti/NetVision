/// Registro de una práctica completada o guardada, mostrado en el
/// historial del estudiante.
class HistoryEntry {
  final String id;
  final String caseTitle;
  final DateTime date;
  final String scenarioSnapshotJson; // NetworkScenario.toJson() serializado
  final bool completed;
  final List<String> problemsFound;

  const HistoryEntry({
    required this.id,
    required this.caseTitle,
    required this.date,
    required this.scenarioSnapshotJson,
    required this.completed,
    this.problemsFound = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'caseTitle': caseTitle,
        'date': date.toIso8601String(),
        'scenarioSnapshotJson': scenarioSnapshotJson,
        'completed': completed,
        'problemsFound': problemsFound,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        caseTitle: json['caseTitle'] as String,
        date: DateTime.parse(json['date'] as String),
        scenarioSnapshotJson: json['scenarioSnapshotJson'] as String? ?? '{}',
        completed: json['completed'] as bool? ?? false,
        problemsFound: (json['problemsFound'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}
