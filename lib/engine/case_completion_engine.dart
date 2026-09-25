import '../models/diagnostic_issue.dart';
import '../models/network_scenario.dart';
import 'addressing_engine.dart';
import 'diagnostics_engine.dart';
import 'dns_engine.dart';
import 'simulation_engine.dart';

/// Resultado de evaluar si un escenario cumple realmente sus condiciones de
/// éxito (no solo "cero problemas detectados").
class CaseCompletionResult {
  final bool success;
  final List<DiagnosticIssue> issues;

  /// Explicaciones legibles de cada requisito que todavía no se cumple.
  /// Vacío cuando [success] es `true`.
  final List<String> unmetRequirements;

  const CaseCompletionResult({
    required this.success,
    required this.issues,
    required this.unmetRequirements,
  });
}

/// Determina si un escenario (caso guiado o topología libre) cumple sus
/// condiciones de éxito.
///
/// A diferencia de una comprobación ingenua basada solo en
/// `DiagnosticsEngine.analyze(scenario).isEmpty`, este motor exige además
/// que se cumplan los requisitos funcionales explícitos que el propio
/// escenario declara ([NetworkScenario.requiredConnectivityChecks],
/// [NetworkScenario.requiredDhcpClientIds],
/// [NetworkScenario.requiredDnsLookups]): conectividad real verificada con
/// [SimulationEngine.simulate], asignaciones DHCP realmente obtenidas y
/// resoluciones DNS realmente exitosas. Un escenario sin requisitos
/// declarados (por ejemplo, el sandbox libre) se evalúa únicamente por
/// ausencia de problemas de diagnóstico.
class CaseCompletionEngine {
  const CaseCompletionEngine._();

  static CaseCompletionResult evaluate(NetworkScenario scenario) {
    final issues = DiagnosticsEngine.analyze(scenario);
    final unmet = <String>[];

    if (issues.isNotEmpty) {
      unmet.add(
          'Network Doctor detectó ${issues.length} condición(es) de configuración que deben corregirse.');
    }

    for (final pair in scenario.requiredConnectivityChecks) {
      if (pair.length != 2) continue;
      final sourceId = pair[0];
      final destId = pair[1];
      final source = scenario.deviceById(sourceId);
      final destination = scenario.deviceById(destId);
      final result = SimulationEngine.simulate(
        scenario: scenario,
        sourceDeviceId: sourceId,
        destinationDeviceId: destId,
      );
      if (!result.delivered) {
        final sourceName = source?.name ?? sourceId;
        final destName = destination?.name ?? destId;
        unmet.add('$sourceName todavía no logra comunicarse con $destName.');
      }
    }

    for (final clientId in scenario.requiredDhcpClientIds) {
      final client = scenario.deviceById(clientId);
      if (client == null) continue;
      final address = client.primaryInterface?.ipv4?.address;
      final hasValidAddress =
          address != null && address.isNotEmpty && AddressingEngine.isValidIpv4(address);
      if (!hasValidAddress) {
        unmet.add('${client.name} todavía no tiene una configuración IPv4 obtenida por DHCP.');
      }
    }

    for (final lookup in scenario.requiredDnsLookups) {
      final clientId = lookup['clientId'];
      final hostname = lookup['hostname'];
      if (clientId == null || hostname == null) continue;
      final client = scenario.deviceById(clientId);
      if (client == null) continue;
      final result = DnsEngine.resolve(
        scenario: scenario,
        hostname: hostname,
        clientDeviceId: clientId,
        clientDnsIp: client.primaryInterface?.ipv4?.dns,
      );
      if (!result.success) {
        unmet.add('${client.name} todavía no resuelve "$hostname" mediante DNS.');
      }
    }

    return CaseCompletionResult(success: unmet.isEmpty, issues: issues, unmetRequirements: unmet);
  }
}
