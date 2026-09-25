import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:netvision/engine/dns_engine.dart';
import 'package:netvision/models/enums.dart';
import 'package:netvision/models/ipv4_configuration.dart';
import 'package:netvision/models/network_device.dart';
import 'package:netvision/models/network_interface.dart';
import 'package:netvision/models/network_link.dart';
import 'package:netvision/models/network_scenario.dart';

NetworkDevice _pc(String id, {String? dns}) {
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
        ipv4: Ipv4Configuration(address: '192.168.1.10', prefixLength: 24, dns: dns),
      ),
    ],
  );
}

NetworkDevice _dnsServer(String id, {String ip = '192.168.1.5', Map<String, String>? records}) {
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
        ipv4: Ipv4Configuration(address: ip, prefixLength: 24),
      ),
    ],
    serverRole: ServerRole.dns,
    dnsRecords: records ?? {'portal.test': '192.168.1.50'},
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

NetworkLink _link(String id, NetworkDevice a, String ifaceA, NetworkDevice b, String ifaceB) {
  return NetworkLink(id: id, deviceAId: a.id, interfaceAId: ifaceA, deviceBId: b.id, interfaceBId: ifaceB);
}

void main() {
  group('DnsEngine', () {
    test('DNS correcto: cliente y servidor conectados, dominio existente', () {
      final pc = _pc('pc', dns: '192.168.1.5');
      final server = _dnsServer('server');
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

      final result = DnsEngine.resolve(
        scenario: scenario,
        hostname: 'portal.test',
        clientDeviceId: 'pc',
        clientDnsIp: '192.168.1.5',
      );

      expect(result.success, true);
      expect(result.resolvedIp, '192.168.1.50');
    });

    test('DNS vacío: el cliente no tiene configurado servidor DNS', () {
      final pc = _pc('pc');
      final server = _dnsServer('server');
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

      final result = DnsEngine.resolve(
        scenario: scenario,
        hostname: 'portal.test',
        clientDeviceId: 'pc',
        clientDnsIp: null,
      );

      expect(result.success, false);
      expect(result.message, contains('no tiene configurado un servidor DNS'));
    });

    test('DNS inexistente: la dirección configurada no pertenece a ningún dispositivo', () {
      final pc = _pc('pc', dns: '192.168.1.99');
      final server = _dnsServer('server');
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

      final result = DnsEngine.resolve(
        scenario: scenario,
        hostname: 'portal.test',
        clientDeviceId: 'pc',
        clientDnsIp: '192.168.1.99',
      );

      expect(result.success, false);
      expect(result.message, contains('no existe en la topología'));
    });

    test('DNS inalcanzable: servidor en otra red sin Relay', () {
      final pc = _pc('pc', dns: '10.0.0.5');
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
      final server = _dnsServer('server', ip: '10.0.0.5');
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

      final result = DnsEngine.resolve(
        scenario: scenario,
        hostname: 'portal.test',
        clientDeviceId: 'pc',
        clientDnsIp: '10.0.0.5',
      );

      expect(result.success, false);
      expect(result.message, contains('no es alcanzable'));
    });

    test('registro DNS con IP inválida almacenada: no crashea, simplemente devuelve el valor guardado', () {
      // Defensa contra datos inválidos preexistentes (p. ej. de una versión
      // anterior sin validación en el editor): resolver nunca debe lanzar
      // una excepción, aunque el valor guardado no sea una IPv4 válida.
      final pc = _pc('pc', dns: '192.168.1.5');
      final server = _dnsServer('server', records: {'roto.test': 'no-es-una-ip'});
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

      DnsResult? result;
      expect(() {
        result = DnsEngine.resolve(
          scenario: scenario,
          hostname: 'roto.test',
          clientDeviceId: 'pc',
          clientDnsIp: '192.168.1.5',
        );
      }, returnsNormally);
      expect(result!.success, true);
      expect(result!.resolvedIp, 'no-es-una-ip');
    });

    test('dominio inexistente: servidor alcanzable pero sin ese registro', () {
      final pc = _pc('pc', dns: '192.168.1.5');
      final server = _dnsServer('server');
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

      final result = DnsEngine.resolve(
        scenario: scenario,
        hostname: 'noexiste.test',
        clientDeviceId: 'pc',
        clientDnsIp: '192.168.1.5',
      );

      expect(result.success, false);
      expect(result.message, contains('No se encontró un registro DNS'));
    });
  });
}
