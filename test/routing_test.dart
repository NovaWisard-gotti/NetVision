import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:netvision/engine/diagnostics_engine.dart';
import 'package:netvision/engine/simulation_engine.dart';
import 'package:netvision/models/enums.dart';
import 'package:netvision/models/ipv4_configuration.dart';
import 'package:netvision/models/network_device.dart';
import 'package:netvision/models/network_interface.dart';
import 'package:netvision/models/network_link.dart';
import 'package:netvision/models/network_scenario.dart';

/// Topología de referencia usada en varias pruebas de enrutamiento:
///
/// hostA (192.168.10.10/24) -- routerA(192.168.10.1/24 | 10.0.0.1/30) --
/// routerB(10.0.0.2/30 | 192.168.20.1/24) -- hostB (192.168.20.10/24)
class _TwoRouterTopology {
  final NetworkDevice hostA;
  final NetworkDevice hostB;
  final NetworkDevice routerA;
  final NetworkDevice routerB;
  final List<NetworkLink> links;

  _TwoRouterTopology()
      : hostA = NetworkDevice(
          id: 'hostA',
          type: DeviceType.pc,
          name: 'HostA',
          position: Offset.zero,
          interfaces: [
            NetworkInterface(
              id: 'hostA-if',
              deviceId: 'hostA',
              name: 'if',
              ipv4: const Ipv4Configuration(
                  address: '192.168.10.10', prefixLength: 24, gateway: '192.168.10.1'),
            ),
          ],
        ),
        hostB = NetworkDevice(
          id: 'hostB',
          type: DeviceType.pc,
          name: 'HostB',
          position: Offset.zero,
          interfaces: [
            NetworkInterface(
              id: 'hostB-if',
              deviceId: 'hostB',
              name: 'if',
              ipv4: const Ipv4Configuration(
                  address: '192.168.20.10', prefixLength: 24, gateway: '192.168.20.1'),
            ),
          ],
        ),
        routerA = NetworkDevice(
          id: 'routerA',
          type: DeviceType.router,
          name: 'RouterA',
          position: Offset.zero,
          interfaces: [
            NetworkInterface(
                id: 'routerA-lan',
                deviceId: 'routerA',
                name: 'LAN',
                ipv4: const Ipv4Configuration(address: '192.168.10.1', prefixLength: 24)),
            NetworkInterface(
                id: 'routerA-wan',
                deviceId: 'routerA',
                name: 'WAN',
                ipv4: const Ipv4Configuration(address: '10.0.0.1', prefixLength: 30)),
          ],
        ),
        routerB = NetworkDevice(
          id: 'routerB',
          type: DeviceType.router,
          name: 'RouterB',
          position: Offset.zero,
          interfaces: [
            NetworkInterface(
                id: 'routerB-wan',
                deviceId: 'routerB',
                name: 'WAN',
                ipv4: const Ipv4Configuration(address: '10.0.0.2', prefixLength: 30)),
            NetworkInterface(
                id: 'routerB-lan',
                deviceId: 'routerB',
                name: 'LAN',
                ipv4: const Ipv4Configuration(address: '192.168.20.1', prefixLength: 24)),
          ],
        ),
        links = [
          NetworkLink(
              id: 'l1', deviceAId: 'hostA', interfaceAId: 'hostA-if', deviceBId: 'routerA', interfaceBId: 'routerA-lan'),
          NetworkLink(
              id: 'l2', deviceAId: 'routerA', interfaceAId: 'routerA-wan', deviceBId: 'routerB', interfaceBId: 'routerB-wan'),
          NetworkLink(
              id: 'l3', deviceAId: 'routerB', interfaceAId: 'routerB-lan', deviceBId: 'hostB', interfaceBId: 'hostB-if'),
        ];

  NetworkScenario buildScenario() => NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [hostA, hostB, routerA, routerB],
        links: links,
      );
}

void main() {
  group('Enrutamiento entre routers', () {
    test('red directamente conectada: HostA llega a RouterA sin rutas estáticas', () {
      final topo = _TwoRouterTopology();
      final scenario = topo.buildScenario();
      final result = SimulationEngine.simulate(
        scenario: scenario,
        sourceDeviceId: 'hostA',
        destinationDeviceId: 'routerA',
      );
      expect(result.delivered, true);
    });

    test('ruta faltante: sin rutas estáticas, HostA no llega a HostB y Network Doctor lo detecta', () {
      final topo = _TwoRouterTopology();
      final scenario = topo.buildScenario();

      final ping = SimulationEngine.simulate(
        scenario: scenario,
        sourceDeviceId: 'hostA',
        destinationDeviceId: 'hostB',
      );
      expect(ping.delivered, false);

      final issues = DiagnosticsEngine.analyze(scenario);
      final missingRouteIssues = issues.where((i) => i.type == IssueType.missingRoute).toList();
      // Ambos routers necesitan una ruta: RouterA hacia 192.168.20.0/24 y
      // RouterB hacia 192.168.10.0/24 (ruta de retorno).
      expect(missingRouteIssues.length, 2);
      expect(missingRouteIssues.any((i) => i.deviceId == 'routerA'), true);
      expect(missingRouteIssues.any((i) => i.deviceId == 'routerB'), true);
    });

    test('ruta estática válida en ambos sentidos: la comunicación funciona y Network Doctor no reporta nada', () {
      final topo = _TwoRouterTopology();
      topo.routerA.routeTable.add({
        'destinationNetwork': '192.168.20.0',
        'prefixLength': 24,
        'exitInterfaceId': 'routerA-wan',
      });
      topo.routerB.routeTable.add({
        'destinationNetwork': '192.168.10.0',
        'prefixLength': 24,
        'exitInterfaceId': 'routerB-wan',
      });
      final scenario = topo.buildScenario();

      final ping = SimulationEngine.simulate(
        scenario: scenario,
        sourceDeviceId: 'hostA',
        destinationDeviceId: 'hostB',
      );
      expect(ping.delivered, true);

      final issues = DiagnosticsEngine.analyze(scenario);
      expect(issues.where((i) => i.type == IssueType.missingRoute), isEmpty);
    });

    test('ruta de retorno faltante: solo RouterA tiene ruta, Network Doctor detecta a RouterB', () {
      final topo = _TwoRouterTopology();
      topo.routerA.routeTable.add({
        'destinationNetwork': '192.168.20.0',
        'prefixLength': 24,
        'exitInterfaceId': 'routerA-wan',
      });
      // RouterB NO tiene ruta de retorno hacia 192.168.10.0/24.
      final scenario = topo.buildScenario();

      final issues = DiagnosticsEngine.analyze(scenario);
      final missingRouteIssues = issues.where((i) => i.type == IssueType.missingRoute).toList();
      expect(missingRouteIssues.length, 1);
      expect(missingRouteIssues.single.deviceId, 'routerB');
    });

    test('interfaz de salida sin conexión (next hop inválido) hace fallar la simulación', () {
      final topo = _TwoRouterTopology();
      // Ruta que apunta a una interfaz que en realidad no tiene ningún enlace.
      topo.routerA.interfaces.add(NetworkInterface(
        id: 'routerA-spare',
        deviceId: 'routerA',
        name: 'Spare',
        ipv4: const Ipv4Configuration(address: '172.16.0.1', prefixLength: 30),
      ));
      topo.routerA.routeTable.add({
        'destinationNetwork': '192.168.20.0',
        'prefixLength': 24,
        'exitInterfaceId': 'routerA-spare',
      });
      final scenario = topo.buildScenario();

      final ping = SimulationEngine.simulate(
        scenario: scenario,
        sourceDeviceId: 'hostA',
        destinationDeviceId: 'hostB',
      );
      expect(ping.delivered, false);
      expect(ping.hops.last.isFailure, true);
    });
  });
}
