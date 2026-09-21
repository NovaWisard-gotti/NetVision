/// Progreso acumulado del estudiante dentro de NetVision.
class ProgressStats {
  int casesCompleted;
  int networksConfigured;
  int packetsSimulated;
  int problemsDiagnosed;
  int subnettingExercisesDone;
  int servicesConfigured; // DHCP/DNS practicados

  /// Dominio por área (0-100), aproximado por número de prácticas.
  Map<String, int> masteryByArea;

  ProgressStats({
    this.casesCompleted = 0,
    this.networksConfigured = 0,
    this.packetsSimulated = 0,
    this.problemsDiagnosed = 0,
    this.subnettingExercisesDone = 0,
    this.servicesConfigured = 0,
    Map<String, int>? masteryByArea,
  }) : masteryByArea = masteryByArea ??
            {
              'IPv4': 0,
              'Subnetting': 0,
              'Switching': 0,
              'Routing': 0,
              'DHCP': 0,
              'DNS': 0,
              'Diagnóstico': 0,
            };

  Map<String, dynamic> toJson() => {
        'casesCompleted': casesCompleted,
        'networksConfigured': networksConfigured,
        'packetsSimulated': packetsSimulated,
        'problemsDiagnosed': problemsDiagnosed,
        'subnettingExercisesDone': subnettingExercisesDone,
        'servicesConfigured': servicesConfigured,
        'masteryByArea': masteryByArea,
      };

  factory ProgressStats.fromJson(Map<String, dynamic> json) => ProgressStats(
        casesCompleted: json['casesCompleted'] as int? ?? 0,
        networksConfigured: json['networksConfigured'] as int? ?? 0,
        packetsSimulated: json['packetsSimulated'] as int? ?? 0,
        problemsDiagnosed: json['problemsDiagnosed'] as int? ?? 0,
        subnettingExercisesDone: json['subnettingExercisesDone'] as int? ?? 0,
        servicesConfigured: json['servicesConfigured'] as int? ?? 0,
        masteryByArea: Map<String, int>.from(
            (json['masteryByArea'] as Map<dynamic, dynamic>? ?? {})),
      );

  void bumpMastery(String area, {int amount = 5}) {
    final current = masteryByArea[area] ?? 0;
    masteryByArea[area] = (current + amount).clamp(0, 100);
  }
}
