import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/diagnostic_issue.dart';
import '../../models/enums.dart';
import '../../models/network_scenario.dart';
import '../widgets/device_visuals_helper.dart';

/// Informe educativo generado al finalizar un escenario: no se limita a
/// una puntuación, sino que resume topología, configuraciones, pruebas y
/// resultado.
class ReportScreen extends StatelessWidget {
  final NetworkScenario scenario;
  final List<DiagnosticIssue> issues;

  const ReportScreen({super.key, required this.scenario, required this.issues});

  @override
  Widget build(BuildContext context) {
    final hostDevices = scenario.devices.where((d) => d.type.supportsIpv4Configuration).toList();
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
              children: [
                Icon(
                  issues.isEmpty ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: issues.isEmpty ? NetVisionColors.successGreen : NetVisionColors.signalYellow,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(issues.isEmpty
                      ? 'La topología no presenta condiciones básicas de error.'
                      : 'Existen ${issues.length} condición(es) por revisar.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: 'Retroalimentación',
            child: Text(_feedbackFor(hostDevices.length, issues)),
          ),
        ],
      ),
    );
  }

  String _feedbackFor(int hostCount, List<DiagnosticIssue> issues) {
    if (issues.isEmpty) {
      return 'Buen trabajo: la topología cumple las condiciones básicas de una red funcional. '
          'Sigue verificando con Packet Journey escenarios de comunicación tanto dentro de la '
          'misma red como hacia otras redes para confirmar que el comportamiento es el esperado.';
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
