import 'package:flutter_test/flutter_test.dart';
import 'package:netvision/data/professional_cases.dart';
import 'package:netvision/engine/diagnostics_engine.dart';
import 'package:netvision/models/enums.dart';
import 'package:netvision/models/ipv4_configuration.dart';
import 'package:netvision/models/network_device.dart';
import 'package:netvision/models/network_interface.dart';
import 'package:netvision/models/network_link.dart';
import 'package:netvision/models/network_scenario.dart';

NetworkDevice _pc(String id, String ip, int prefix, {String? dns}) {
  return NetworkDevice(
    id: id,
    type: DeviceType.pc,
    name: id,
    position: Offset.zero,
    interfaces: [
      NetworkInterface(
        id: '$id-if',
        deviceId: id,
        name: 'if',
        ipv4: Ipv4Configuration(address: ip, prefixLength: prefix, dns: dns),
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
      for (var i = 0; i < ports; i++) NetworkInterface(id: '$id-p$i', deviceId: id, name: 'p$i'),
    ],
  );
}

NetworkLink _link(String id, NetworkDevice a, String ifaceA, NetworkDevice b, String ifaceB) {
  return NetworkLink(id: id, deviceAId: a.id, interfaceAId: ifaceA, deviceBId: b.id, interfaceBId: ifaceB);
}

void main() {
  group('DiagnosticsEngine - incompatibleSubnets', () {
    test('dos PCs en el mismo switch con redes incompatibles se detectan', () {
      final pcA = _pc('pcA', '192.168.1.10', 24);
      final pcB = _pc('pcB', '192.168.2.10', 24); // Red distinta, mismo cable físico.
      final sw = _switch('sw', 2);
      final scenario = NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [pcA, pcB, sw],
        links: [
          _link('l1', pcA, 'pcA-if', sw, 'sw-p0'),
          _link('l2', pcB, 'pcB-if', sw, 'sw-p1'),
        ],
      );

      final issues = DiagnosticsEngine.analyze(scenario);
      expect(issues.any((i) => i.type == IssueType.incompatibleSubnets), true);
    });

    test('dos PCs en la misma red no generan el problema', () {
      final pcA = _pc('pcA', '192.168.1.10', 24);
      final pcB = _pc('pcB', '192.168.1.20', 24);
      final sw = _switch('sw', 2);
      final scenario = NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [pcA, pcB, sw],
        links: [
          _link('l1', pcA, 'pcA-if', sw, 'sw-p0'),
          _link('l2', pcB, 'pcB-if', sw, 'sw-p1'),
        ],
      );

      final issues = DiagnosticsEngine.analyze(scenario);
      expect(issues.any((i) => i.type == IssueType.incompatibleSubnets), false);
    });
  });

  group('DiagnosticsEngine - wrongDns', () {
    test('DNS con formato inválido se detecta', () {
      final pc = _pc('pc', '192.168.1.10', 24, dns: 'no-es-una-ip');
      final scenario = NetworkScenario(id: 's', title: 't', objective: '', devices: [pc]);
      final issues = DiagnosticsEngine.analyze(scenario);
      expect(issues.any((i) => i.type == IssueType.wrongDns), true);
    });

    test('DNS apuntando a un dispositivo inexistente se detecta', () {
      final pc = _pc('pc', '192.168.1.10', 24, dns: '192.168.1.99');
      final sw = _switch('sw', 1);
      final scenario = NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [pc, sw],
        links: [_link('l1', pc, 'pc-if', sw, 'sw-p0')],
      );
      final issues = DiagnosticsEngine.analyze(scenario);
      expect(issues.any((i) => i.type == IssueType.wrongDns), true);
    });

    test('DNS apuntando a un dispositivo sin servicio DNS se detecta', () {
      final pc = _pc('pc', '192.168.1.10', 24, dns: '192.168.1.20');
      final other = _pc('other', '192.168.1.20', 24); // No presta servicio DNS.
      final sw = _switch('sw', 2);
      final scenario = NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [pc, other, sw],
        links: [
          _link('l1', pc, 'pc-if', sw, 'sw-p0'),
          _link('l2', other, 'other-if', sw, 'sw-p1'),
        ],
      );
      final issues = DiagnosticsEngine.analyze(scenario);
      expect(issues.any((i) => i.type == IssueType.wrongDns), true);
    });

    test('DNS vacío no genera un problema por sí solo (su obligatoriedad depende del caso)', () {
      final pc = _pc('pc', '192.168.1.10', 24);
      final scenario = NetworkScenario(id: 's', title: 't', objective: '', devices: [pc]);
      final issues = DiagnosticsEngine.analyze(scenario);
      expect(issues.any((i) => i.type == IssueType.wrongDns), false);
    });
  });

  group('DiagnosticsEngine - duplicateIp', () {
    test('dos dispositivos con la misma IP se detectan', () {
      final pcA = _pc('pcA', '192.168.1.10', 24);
      final pcB = _pc('pcB', '192.168.1.10', 24); // Misma dirección.
      final sw = _switch('sw', 2);
      final scenario = NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [pcA, pcB, sw],
        links: [
          _link('l1', pcA, 'pcA-if', sw, 'sw-p0'),
          _link('l2', pcB, 'pcB-if', sw, 'sw-p1'),
        ],
      );
      final issues = DiagnosticsEngine.analyze(scenario);
      final duplicates = issues.where((i) => i.type == IssueType.duplicateIp).toList();
      expect(duplicates.length, 2); // Se reporta para cada dispositivo involucrado.
    });

    test('direcciones distintas no generan el problema', () {
      final pcA = _pc('pcA', '192.168.1.10', 24);
      final pcB = _pc('pcB', '192.168.1.11', 24);
      final scenario = NetworkScenario(id: 's', title: 't', objective: '', devices: [pcA, pcB]);
      final issues = DiagnosticsEngine.analyze(scenario);
      expect(issues.any((i) => i.type == IssueType.duplicateIp), false);
    });
  });

  group('DiagnosticsEngine - disabledLink', () {
    test('un enlace deshabilitado se detecta', () {
      final pcA = _pc('pcA', '192.168.1.10', 24);
      final sw = _switch('sw', 1);
      final link = _link('l1', pcA, 'pcA-if', sw, 'sw-p0')..enabled = false;
      final scenario = NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [pcA, sw],
        links: [link],
      );
      final issues = DiagnosticsEngine.analyze(scenario);
      expect(issues.any((i) => i.type == IssueType.disabledLink), true);
    });

    test('un enlace habilitado no genera el problema', () {
      final pcA = _pc('pcA', '192.168.1.10', 24);
      final sw = _switch('sw', 1);
      final scenario = NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [pcA, sw],
        links: [_link('l1', pcA, 'pcA-if', sw, 'sw-p0')],
      );
      final issues = DiagnosticsEngine.analyze(scenario);
      expect(issues.any((i) => i.type == IssueType.disabledLink), false);
    });
  });

  group('DiagnosticsEngine - isolatedDevice', () {
    test('un dispositivo sin ninguna conexión se detecta (si hay más de un dispositivo)', () {
      final pcA = _pc('pcA', '192.168.1.10', 24);
      final pcB = _pc('pcB', '192.168.1.11', 24); // Sin enlaces.
      final scenario = NetworkScenario(id: 's', title: 't', objective: '', devices: [pcA, pcB]);
      final issues = DiagnosticsEngine.analyze(scenario);
      final isolated = issues.where((i) => i.type == IssueType.isolatedDevice).toList();
      expect(isolated.length, 2);
    });

    test('un único dispositivo en el escenario no se marca como aislado', () {
      final pcA = _pc('pcA', '192.168.1.10', 24);
      final scenario = NetworkScenario(id: 's', title: 't', objective: '', devices: [pcA]);
      final issues = DiagnosticsEngine.analyze(scenario);
      expect(issues.any((i) => i.type == IssueType.isolatedDevice), false);
    });

    test('un dispositivo conectado no se marca como aislado', () {
      final pcA = _pc('pcA', '192.168.1.10', 24);
      final sw = _switch('sw', 1);
      final scenario = NetworkScenario(
        id: 's',
        title: 't',
        objective: '',
        devices: [pcA, sw],
        links: [_link('l1', pcA, 'pcA-if', sw, 'sw-p0')],
      );
      final issues = DiagnosticsEngine.analyze(scenario);
      expect(issues.any((i) => i.type == IssueType.isolatedDevice), false);
    });
  });

  group('DiagnosticsEngine - sin falsos positivos en los casos profesionales por defecto', () {
    test('ninguno de los 5 casos genera incompatibleSubnets o missingRoute en su topología inicial', () {
      for (final scenario in buildProfessionalCases()) {
        final issues = DiagnosticsEngine.analyze(scenario);
        final structural = issues
            .where((i) => i.type == IssueType.incompatibleSubnets || i.type == IssueType.missingRoute)
            .toList();
        expect(structural, isEmpty,
            reason: '${scenario.title} no debería tener problemas estructurales por defecto: $structural');
      }
    });
  });
}
