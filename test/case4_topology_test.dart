import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:netvision/data/professional_cases.dart';
import 'package:netvision/engine/case_completion_engine.dart';
import 'package:netvision/engine/dhcp_engine.dart';
import 'package:netvision/engine/diagnostics_engine.dart';
import 'package:netvision/engine/dns_engine.dart';
import 'package:netvision/engine/simulation_engine.dart';
import 'package:netvision/models/enums.dart';
import 'package:netvision/models/network_scenario.dart';
import 'package:netvision/persistence/local_storage_service.dart';
import 'package:netvision/state/case_completion_controller.dart';
import 'package:netvision/state/case_progress_provider.dart';
import 'package:netvision/state/progress_provider.dart';
import 'package:netvision/state/storage_provider.dart';

NetworkScenario _case4() => buildProfessionalCases().firstWhere((c) => c.caseNumber == 4);

/// Aplica una solicitud DHCP real a [clientId] y escribe la configuración
/// obtenida en su interfaz, tal como hace la UI del Workspace.
void _applyDhcp(NetworkScenario scenario, String clientId) {
  final client = scenario.deviceById(clientId)!;
  final result = DhcpEngine.requestAddress(scenario: scenario, client: client);
  expect(result.success, true, reason: 'DHCP debería funcionar: ${result.message}');
  final iface = client.primaryInterface!;
  iface.ipv4 = iface.ipv4!.copyWith(
    address: result.assignedIp,
    prefixLength: result.prefixLength,
    gateway: result.gateway,
    dns: result.dns,
  );
}

void main() {
  group('Caso 4 — topología', () {
    test('Router — Switch — {Servidor, PC1, PC2}, cada uno con su propia interfaz', () {
      final scenario = _case4();

      final server = scenario.deviceById('c4-server')!;
      final router = scenario.deviceById('c4-router')!;
      final sw = scenario.deviceById('c4-sw')!;
      final pcA = scenario.deviceById('c4-pcA')!;
      final pcB = scenario.deviceById('c4-pcB')!;

      expect(router.type, DeviceType.router);
      expect(sw.type, DeviceType.switchDevice);
      expect(server.type, DeviceType.server);

      // El router tiene exactamente una interfaz, y esa interfaz participa
      // en un único enlace (nunca se reutiliza para dos conexiones).
      expect(router.interfaces.length, 1);
      final routerIfaceId = router.interfaces.single.id;
      final linksUsingRouterIface =
          scenario.links.where((l) => l.interfaceAId == routerIfaceId || l.interfaceBId == routerIfaceId);
      expect(linksUsingRouterIface.length, 1);

      // El router se conecta directamente al switch (no al servidor).
      final routerLink = linksUsingRouterIface.single;
      expect({routerLink.deviceAId, routerLink.deviceBId}, {router.id, sw.id});

      // El servidor, PC1 y PC2 cuelgan del switch (no del router).
      for (final device in [server, pcA, pcB]) {
        final link = scenario.links.singleWhere((l) => l.connects(device.id));
        expect({link.deviceAId, link.deviceBId}, {device.id, sw.id},
            reason: '${device.name} debe estar conectado al switch, no directamente al router.');
      }

      // Exactamente 4 enlaces: router-switch, servidor-switch, pc1-switch, pc2-switch.
      expect(scenario.links.length, 4);
    });
  });

  group('Caso 4 — flujo funcional completo', () {
    test('PC1 y PC2 obtienen DHCP con direcciones válidas y distintas', () {
      final scenario = _case4();
      _applyDhcp(scenario, 'c4-pcA');
      _applyDhcp(scenario, 'c4-pcB');

      final pcA = scenario.deviceById('c4-pcA')!;
      final pcB = scenario.deviceById('c4-pcB')!;
      final ipA = pcA.primaryInterface!.ipv4!.address;
      final ipB = pcB.primaryInterface!.ipv4!.address;

      expect(ipA, isNotEmpty);
      expect(ipB, isNotEmpty);
      expect(ipA, isNot(ipB));
      expect(pcA.primaryInterface!.ipv4!.gateway, '192.168.5.1');
      expect(pcB.primaryInterface!.ipv4!.gateway, '192.168.5.1');
      expect(pcA.primaryInterface!.ipv4!.dns, '192.168.5.5');
    });

    test('DNS resuelve "portal.universidad.test" una vez que el cliente tiene DHCP', () {
      final scenario = _case4();
      _applyDhcp(scenario, 'c4-pcA');

      final result = DnsEngine.resolve(
        scenario: scenario,
        hostname: 'portal.universidad.test',
        clientDeviceId: 'c4-pcA',
        clientDnsIp: scenario.deviceById('c4-pcA')!.primaryInterface!.ipv4!.dns,
      );

      expect(result.success, true);
      expect(result.resolvedIp, '192.168.5.5');
    });

    test('Ping (SimulationEngine.simulate) funciona entre PC1, PC2 y el servidor tras el DHCP', () {
      final scenario = _case4();
      _applyDhcp(scenario, 'c4-pcA');
      _applyDhcp(scenario, 'c4-pcB');

      final pingToPeer = SimulationEngine.simulate(
          scenario: scenario, sourceDeviceId: 'c4-pcA', destinationDeviceId: 'c4-pcB');
      final pingToServer = SimulationEngine.simulate(
          scenario: scenario, sourceDeviceId: 'c4-pcA', destinationDeviceId: 'c4-server');

      // Packet Journey usa exactamente este mismo motor de simulación, así
      // que un resultado entregado aquí implica que también funciona ahí.
      expect(pingToPeer.delivered, true, reason: pingToPeer.summary);
      expect(pingToServer.delivered, true, reason: pingToServer.summary);
    });

    test('Network Doctor no genera falsos positivos una vez configurado el DHCP', () {
      final scenario = _case4();
      _applyDhcp(scenario, 'c4-pcA');
      _applyDhcp(scenario, 'c4-pcB');

      final issues = DiagnosticsEngine.analyze(scenario);
      expect(issues, isEmpty, reason: 'No debería haber problemas: $issues');
    });

    test('El informe (CaseCompletionEngine) considera el caso correcto solo tras completar DHCP+DNS', () {
      final scenario = _case4();

      final before = CaseCompletionEngine.evaluate(scenario);
      expect(before.success, false);

      _applyDhcp(scenario, 'c4-pcA');
      _applyDhcp(scenario, 'c4-pcB');

      final after = CaseCompletionEngine.evaluate(scenario);
      expect(after.success, true, reason: after.unmetRequirements.join('; '));
      expect(after.issues, isEmpty);
    });
  });

  group('Caso 4 — registro de finalización', () {
    testWidgets('el Caso 4 se registra como completado exactamente una vez', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();

      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageServiceProvider.overrideWithValue(storage)],
          child: MaterialApp(
            home: Consumer(builder: (context, r, _) {
              ref = r;
              return const SizedBox.shrink();
            }),
          ),
        ),
      );

      final scenario = _case4();

      // Antes de configurar DHCP, no debe registrarse como completado.
      final tooEarly = await evaluateAndRegisterCaseCompletion(ref, scenario);
      expect(tooEarly, false);
      expect(ref.read(caseProgressProvider).contains(4), false);

      _applyDhcp(scenario, 'c4-pcA');
      _applyDhcp(scenario, 'c4-pcB');

      final completedNow = await evaluateAndRegisterCaseCompletion(ref, scenario);
      expect(completedNow, true);
      expect(ref.read(caseProgressProvider), {4});
      expect(ref.read(progressNotifierProvider).casesCompleted, 1);

      // Evaluarlo de nuevo (ya resuelto) no debe registrarlo por segunda vez.
      final again = await evaluateAndRegisterCaseCompletion(ref, scenario);
      expect(again, false);
      expect(ref.read(caseProgressProvider), {4});
      expect(ref.read(progressNotifierProvider).casesCompleted, 1);
    });
  });
}
