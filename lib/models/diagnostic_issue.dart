import 'enums.dart';

/// Un problema detectado (o inyectado por Network Doctor) dentro de una
/// topología.
class DiagnosticIssue {
  final IssueType type;
  final String deviceId;
  final String description;
  final String hint;

  const DiagnosticIssue({
    required this.type,
    required this.deviceId,
    required this.description,
    required this.hint,
  });
}
