import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../engine/case_completion_engine.dart';
import '../../models/diagnostic_issue.dart';
import '../../models/enums.dart';
import '../../models/network_scenario.dart';
import '../widgets/device_visuals_helper.dart';

/// Informe educativo generado al finalizar un escenario: no se limita a
/// una puntuación, sino que resume topología, configuraciones, pruebas y
/// resultado. El resultado final nunca depende únicamente de que
/// Network Doctor no haya encontrado problemas: también exige que se
/// cumplan los requisitos funcionales reales del caso (conectividad, DHCP,
/// DNS), evitando falsos positivos como "0 problemas -> todo correcto"
/// cuando en realidad Ping o Packet Journey seguirían fallando.
class ReportScreen extends StatelessWidget {
  final NetworkScenario scenario;
  final CaseCompletionResult completion;

  const ReportScreen({super.key, required this.scenario, required this.completion});

  List<DiagnosticIssue> get issues => completion.issues;

  @override
  Widget build(BuildContext context) {
    final success = completion.success;
    return Scaffold(
      appBar: AppBar(title: const Text('Informe del caso')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(scenario.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(scenario.objective, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),

          _SectionCard(
            title: 'Topología',
            child: Text(
              '${scenario.devices.length} dispositivo(s) · ${scenario.links.length} conexión(es)',
            ),
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: 'Dispositivos y configuración',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final d in scenario.devices)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(DeviceVisualsHelper.iconFor(d.type),
                            size: 18, color: DeviceVisualsHelper.colorFor(d.type)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${d.name} (${d.type.label})'
                            '${d.primaryInterface?.ipv4?.address.isNotEmpty == true ? " — ${d.primaryInterface!.ipv4!.address}/${d.primaryInterface!.ipv4!.prefixLength}" : ""}'
                            '${d.manuallyDisconnected ? " · desconectado" : ""}',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: 'Problemas encontrados',
            child: issues.isEmpty
                ? const Text('No se detectaron problemas de configuración.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: issues
                        .map((i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text('• ${i.type.label}: ${i.description}'),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: 'Resultado final',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: success ? NetVisionColors.successGreen : NetVisionColors.signalYellow,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(success
                      ? 'El caso cumple sus condiciones de éxito: no hay problemas de configuración '
                          'y las pruebas funcionales requeridas (conectividad, DHCP y/o DNS) fueron exitosas.'
                      : 'Todavía faltan condiciones por cumplir para considerar este caso resuelto.'),
                ),
              ],
            ),
          ),
          if (!success && completion.unmetRequirements.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Pendiente por cumplir',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: completion.unmetRequirements
                    .map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text('• $r'),
                        ))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),

          _SectionCard(
            title: 'Retroalimentación',
            child: Text(_feedbackFor(success, issues)),
          ),
        ],
      ),
    );
  }

  String _feedbackFor(bool success, List<DiagnosticIssue> issues) {
    if (success) {
      return 'Buen trabajo: la topología cumple las condiciones básicas de una red funcional y las '
          'pruebas requeridas fueron exitosas. Sigue verificando con Packet Journey otros escenarios '
          'de comunicación para confirmar que el comportamiento es el esperado.';
    }
    if (issues.isEmpty) {
      return 'Network Doctor no encontró problemas de configuración, pero todavía falta comprobar '
          'que las pruebas funcionales del caso (conectividad, DHCP y/o DNS) funcionen realmente. '
          'Revisa la sección "Pendiente por cumplir" antes de considerar el caso terminado.';
    }
    final types = issues.map((i) => i.type.label).toSet().join(', ');
    return 'Se detectaron condiciones relacionadas con: $types. Revisa cada dispositivo señalado, '
        'corrige su configuración y vuelve a validar la topología antes de considerar el caso '
        'terminado.';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
