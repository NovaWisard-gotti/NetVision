import 'package:flutter_test/flutter_test.dart';
import 'package:netvision/data/professional_cases.dart';
import 'package:netvision/engine/case_completion_engine.dart';
import 'package:netvision/engine/dhcp_engine.dart';
import 'package:netvision/engine/dns_engine.dart';
import 'package:netvision/models/network_scenario.dart';

/// Aplica una solicitud DHCP real (motor real, no un valor simulado a mano)
/// a [clientId] dentro de [scenario] y escribe la configuración obtenida en
/// su interfaz principal, tal como hace la UI del Workspace.
void _applyDhcp(NetworkScenario scenario, String clientId) {
  final client = scenario.deviceById(clientId)!;
  final result = DhcpEngine.requestAddress(scenario: scenario, client: client);
  expect(result.success, true, reason: 'La solicitud DHCP de prueba debería tener éxito: ${result.message}');
  final iface = client.primaryInterface!;
  iface.ipv4 = iface.ipv4!.copyWith(
    address: result.assignedIp,
    prefixLength: result.prefixLength,
    gateway: result.gateway,
    dns: result.dns,
  );
}

NetworkScenario _caseByNumber(int number) =>
    buildProfessionalCases().firstWhere((c) => c.caseNumber == number);

void main() {
  group('CaseCompletionEngine - los 5 casos profesionales', () {
    test('Caso 1: se completa apenas se evalúa, porque su topología ya es correcta por diseño', () {
      final result = CaseCompletionEngine.evaluate(_caseByNumber(1));
      expect(result.success, true, reason: result.unmetRequirements.join('; '));
    });

    test('Caso 2: se completa apenas se evalúa, porque su topología ya es correcta por diseño', () {
      final result = CaseCompletionEngine.evaluate(_caseByNumber(2));
      expect(result.success, true, reason: result.unmetRequirements.join('; '));
    });

    test('Caso 3: se completa apenas se evalúa, porque su topología ya es correcta por diseño', () {
      final result = CaseCompletionEngine.evaluate(_caseByNumber(3));
      expect(result.success, true, reason: result.unmetRequirements.join('; '));
    });

    test('Caso 4: NO se completa hasta que ambos clientes obtengan una configuración DHCP válida', () {
      final scenario = _caseByNumber(4);

      final before = CaseCompletionEngine.evaluate(scenario);
      expect(before.success, false);
      expect(before.unmetRequirements, isNotEmpty);

      _applyDhcp(scenario, 'c4-pcA');
      final afterOnlyOneClient = CaseCompletionEngine.evaluate(scenario);
      expect(afterOnlyOneClient.success, false,
          reason: 'PC-Empleado-02 todavía no tiene DHCP: ${afterOnlyOneClient.unmetRequirements}');

      _applyDhcp(scenario, 'c4-pcB');

      // Con ambos clientes configurados por DHCP (dirección, gateway y DNS
      // entregados por el servidor), la conectividad y la resolución DNS
      // declaradas como requisito ya funcionan realmente, verificado con el
      // motor real de DNS (no una simulación a mano).
      final dnsCheck = DnsEngine.resolve(
        scenario: scenario,
        hostname: 'portal.universidad.test',
        clientDeviceId: 'c4-pcA',
        clientDnsIp: scenario.deviceById('c4-pcA')!.primaryInterface!.ipv4!.dns,
      );
      expect(dnsCheck.success, true, reason: dnsCheck.message);

      final after = CaseCompletionEngine.evaluate(scenario);
      expect(after.success, true, reason: after.unmetRequirements.join('; '));
    });

    test('Caso 5: NO se completa mientras persiste la falla oculta del gateway', () {
      final scenario = _caseByNumber(5);
      final before = CaseCompletionEngine.evaluate(scenario);
      expect(before.success, false);

      // El estudiante corrige la falla: el gateway de PC-Diseño-02 debe
      // apuntar al router real (192.168.7.1), no a una IP inexistente.
      final pcB = scenario.deviceById('c5-pcB')!;
      final iface = pcB.primaryInterface!;
      iface.ipv4 = iface.ipv4!.copyWith(gateway: '192.168.7.1');

      final after = CaseCompletionEngine.evaluate(scenario);
      expect(after.success, true, reason: after.unmetRequirements.join('; '));
    });
  });
}
