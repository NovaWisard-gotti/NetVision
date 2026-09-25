import 'package:flutter_test/flutter_test.dart';
import 'package:netvision/engine/dhcp_engine.dart';
import 'package:netvision/models/enums.dart';
import 'package:netvision/models/ipv4_configuration.dart';
import 'package:netvision/models/network_device.dart';
import 'package:netvision/models/network_interface.dart';
import 'package:netvision/models/network_link.dart';
import 'package:netvision/models/network_scenario.dart';

NetworkDevice _pc(String id, {String? address, String? dns}) {
  return NetworkDevice(
    id: id,
    type: DeviceType.pc,
    name: id,
    position: Offset.zero,
    interfaces: [
      NetworkInterface(
        id: '$id-if',
        deviceId: id,
        name: 'Interfaz',
        ipv4: Ipv4Configuration(
          address: address ?? '',
          prefixLength: 24,
          dns: dns,
          mode: address == null ? AddressMode.dhcp : AddressMode.static,
        ),
      ),
    ],
  );
}

NetworkDevice _switch(String id, int ports) {
  return NetworkDevice(
    id: id,
    type: DeviceType.switchDevice,
    name: id,
    position: Offset.zero,
    interfaces: [
      for (var i = 0; i < ports; i++)
        NetworkInterface(id: '$id-p$i', deviceId: id, name: 'Puerto $i'),
    ],
  );
}

NetworkDevice _dhcpServer(
  String id, {
  required String start,
  required String end,
  int prefix = 24,
  String gateway = '192.168.1.1',
  String? dns,
  String serverIp = '192.168.1.5',
}) {
  return NetworkDevice(
    id: id,
    type: DeviceType.server,
    name: id,
    position: Offset.zero,
    interfaces: [
      NetworkInterface(
        id: '$id-if',
        deviceId: id,
        name: 'Interfaz',
        ipv4: Ipv4Configuration(address: serverIp, prefixLength: prefix, gateway: gateway),
      ),
    ],
    serverRole: ServerRole.dhcp,
    dhcpPoolStart: start,
    dhcpPoolEnd: end,
    dhcpPrefixLength: prefix,
    dhcpGateway: gateway,
    dhcpDns: dns,
  );
}

NetworkLink _link(String id, NetworkDevice a, String ifaceA, NetworkDevice b, String ifaceB) {
  return NetworkLink(id: id, deviceAId: a.id, interfaceAId: ifaceA, deviceBId: b.id, interfaceBId: ifaceB);
}

void main() {
  group('DhcpEngine', () {
    test('cliente y servidor conectados por el mismo switch reciben una IP del pool', () {
      final pc = _pc('pc');
      final server = _dhcpServer('server', start: '192.168.1.100', end: '192.168.1.150');
      final sw = _switch('sw', 2);
      final scenario = NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [pc, server, sw],
        links: [
          _link('l1', pc, 'pc-if', sw, 'sw-p0'),
          _link('l2', server, 'server-if', sw, 'sw-p1'),
        ],
      );

      final result = DhcpEngine.requestAddress(scenario: scenario, client: pc);

      expect(result.success, true);
      expect(result.assignedIp, isNotNull);
      final assignedInt = result.assignedIp!.split('.').map(int.parse).toList();
      expect(assignedInt[3], inInclusiveRange(100, 150));
      expect(result.gateway, '192.168.1.1');
    });

    test('cliente aislado del servidor (redes separadas) no recibe DHCP', () {
      final pc = _pc('pc');
      final server = _dhcpServer('server', start: '192.168.1.100', end: '192.168.1.150');
      final swA = _switch('swA', 1);
      final swB = _switch('swB', 1);
      final scenario = NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [pc, server, swA, swB],
        links: [
          _link('l1', pc, 'pc-if', swA, 'swA-p0'),
          _link('l2', server, 'server-if', swB, 'swB-p0'),
          // Nótese que no existe ningún enlace entre swA y swB.
        ],
      );

      final result = DhcpEngine.requestAddress(scenario: scenario, client: pc);

      expect(result.success, false);
      expect(result.message, contains('otra red'));
    });

    test('servidor en otra LAN a través de un router tampoco entrega DHCP (sin Relay)', () {
      final pc = _pc('pc');
      final server = _dhcpServer('server', start: '10.0.0.100', end: '10.0.0.150', prefix: 24, gateway: '10.0.0.1', serverIp: '10.0.0.5');
      final router = NetworkDevice(
        id: 'router',
        type: DeviceType.router,
        name: 'router',
        position: Offset.zero,
        interfaces: [
          NetworkInterface(id: 'router-if1', deviceId: 'router', name: 'if1', ipv4: const Ipv4Configuration(address: '192.168.1.1', prefixLength: 24)),
          NetworkInterface(id: 'router-if2', deviceId: 'router', name: 'if2', ipv4: const Ipv4Configuration(address: '10.0.0.1', prefixLength: 24)),
        ],
      );
      final scenario = NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [pc, router, server],
        links: [
          _link('l1', pc, 'pc-if', router, 'router-if1'),
          _link('l2', router, 'router-if2', server, 'server-if'),
        ],
      );

      final result = DhcpEngine.requestAddress(scenario: scenario, client: pc);

      expect(result.success, false);
      expect(result.message, contains('otra red'));
    });

    test('pool agotado: todas las direcciones ya están en uso', () {
      final pc = _pc('pc');
      // Único host posible del pool ya ocupado por otro dispositivo.
      final other = _pc('other', address: '192.168.1.100');
      final server = _dhcpServer('server', start: '192.168.1.100', end: '192.168.1.100');
      final sw = _switch('sw', 3);
      final scenario = NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [pc, other, server, sw],
        links: [
          _link('l1', pc, 'pc-if', sw, 'sw-p0'),
          _link('l2', other, 'other-if', sw, 'sw-p1'),
          _link('l3', server, 'server-if', sw, 'sw-p2'),
        ],
      );

      final result = DhcpEngine.requestAddress(scenario: scenario, client: pc);

      expect(result.success, false);
      expect(result.message, contains('no tiene direcciones disponibles'));
    });

    test('nunca entrega direcciones duplicadas: evita la IP ya usada por otro dispositivo', () {
      final pc = _pc('pc');
      final other = _pc('other', address: '192.168.1.100');
      final server = _dhcpServer('server', start: '192.168.1.100', end: '192.168.1.101');
      final sw = _switch('sw', 3);
      final scenario = NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [pc, other, server, sw],
        links: [
          _link('l1', pc, 'pc-if', sw, 'sw-p0'),
          _link('l2', other, 'other-if', sw, 'sw-p1'),
          _link('l3', server, 'server-if', sw, 'sw-p2'),
        ],
      );

      final result = DhcpEngine.requestAddress(scenario: scenario, client: pc);

      expect(result.success, true);
      expect(result.assignedIp, '192.168.1.101');
    });

    test('pool inválido (rango invertido) se rechaza con un mensaje educativo', () {
      final pc = _pc('pc');
      final server = _dhcpServer('server', start: '192.168.1.150', end: '192.168.1.100');
      final sw = _switch('sw', 2);
      final scenario = NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [pc, server, sw],
        links: [
          _link('l1', pc, 'pc-if', sw, 'sw-p0'),
          _link('l2', server, 'server-if', sw, 'sw-p1'),
        ],
      );

      final result = DhcpEngine.requestAddress(scenario: scenario, client: pc);

      expect(result.success, false);
      expect(result.message, contains('pool DHCP'));
    });

    test('validatePool rechaza redes/broadcast/gateway dentro del rango', () {
      expect(
        DhcpEngine.validatePool(start: '192.168.1.0', end: '192.168.1.50', prefixLength: 24, gateway: '192.168.1.1'),
        isNotNull,
      );
      expect(
        DhcpEngine.validatePool(start: '192.168.1.100', end: '192.168.1.255', prefixLength: 24, gateway: '192.168.1.1'),
        isNotNull,
      );
      expect(
        DhcpEngine.validatePool(start: '192.168.1.1', end: '192.168.1.150', prefixLength: 24, gateway: '192.168.1.1'),
        isNotNull,
      );
      expect(
        DhcpEngine.validatePool(start: '192.168.1.100', end: '192.168.1.150', prefixLength: 24, gateway: '192.168.1.1'),
        isNull,
      );
    });

    test('validatePool rechaza rangos absurdamente grandes para evitar congelar la app', () {
      expect(
        DhcpEngine.validatePool(start: '10.0.0.1', end: '10.255.255.254', prefixLength: 8, gateway: '10.0.0.254'),
        isNotNull,
      );
    });

    test('validatePool exige un gateway válido', () {
      expect(
        DhcpEngine.validatePool(start: '192.168.1.100', end: '192.168.1.150', prefixLength: 24, gateway: ''),
        isNotNull,
      );
      expect(
        DhcpEngine.validatePool(start: '192.168.1.100', end: '192.168.1.150', prefixLength: 24, gateway: 'hola'),
        isNotNull,
      );
    });
  });
}
