import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/diagnostic_issue.dart';
import '../../models/enums.dart';

/// Hoja inferior que muestra el resultado de "Validar topología": una
/// lista de condiciones básicas detectadas, sin corregir nada
/// automáticamente (el estudiante debe analizar y decidir).
class TopologyValidationSheet extends StatelessWidget {
  final List<DiagnosticIssue> issues;

  const TopologyValidationSheet({super.key, required this.issues});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  Icon(
                    issues.isEmpty ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: issues.isEmpty ? NetVisionColors.successGreen : NetVisionColors.signalYellow,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    issues.isEmpty
                        ? 'No se detectaron problemas'
                        : '${issues.length} condición(es) detectada(s)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (issues.isEmpty)
                const Text(
                    'La topología no presenta condiciones básicas de error. Esto no garantiza que la '
                    'red funcione exactamente como esperas: sigue probando con Packet Journey.'),
              for (final issue in issues)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.error_outline, color: NetVisionColors.dangerRed),
                    title: Text(issue.type.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${issue.description}\nSugerencia: ${issue.hint}'),
                    isThreeLine: true,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
