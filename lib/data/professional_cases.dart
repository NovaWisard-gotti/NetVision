import 'dart:ui';
import '../models/enums.dart';
import '../models/ipv4_configuration.dart';
import '../models/network_device.dart';
import '../models/network_interface.dart';
import '../models/network_link.dart';
import '../models/network_scenario.dart';

/// Los cinco casos profesionales exigidos para el MVP de NetVision.
///
/// Cada caso se construye como una topología completa y funcional (no una
/// simple descripción): el estudiante la abre ya armada en el Workspace,
/// puede inspeccionarla, probarla, modificarla y —en el Caso 5— debe
/// diagnosticarla y corregirla.
List<NetworkScenario> buildProfessionalCases() {
  return [
    _case1LaboratorioUniversitario(),
    _case2DosDepartamentos(),
    _case3OficinaEnCrecimiento(),
    _case4ServiciosDeEmpresa(),
    _case5RedConFallas(),
  ];
}

NetworkInterface _hostIface(String deviceId, String id, String ip, int prefix,
    {String? gateway, String? dns, AddressMode mode = AddressMode.static}) {
  return NetworkInterface(
    id: id,
    deviceId: deviceId,
    name: 'Interfaz',
    ipv4: Ipv4Configuration(
      address: ip,
      prefixLength: prefix,
      gateway: gateway,
      dns: dns,
      mode: mode,
    ),
  );
}

NetworkScenario _case1LaboratorioUniversitario() {
  const pcA = 'c1-pcA', pcB = 'c1-pcB', pcC = 'c1-pcC', sw = 'c1-sw';
  final devices = [
    NetworkDevice(
      id: pcA,
      type: DeviceType.pc,
      name: 'PC-Lab-01',
      position: const Offset(120, 340),
      interfaces: [_hostIface(pcA, '$pcA-if', '192.168.10.10', 24)],
    ),
    NetworkDevice(
      id: pcB,
      type: DeviceType.pc,
      name: 'PC-Lab-02',
      position: const Offset(320, 460),
      interfaces: [_hostIface(pcB, '$pcB-if', '192.168.10.11', 24)],
    ),
    NetworkDevice(
      id: pcC,
      type: DeviceType.laptop,
      name: 'Laptop-Lab-03',
      position: const Offset(520, 340),
      interfaces: [_hostIface(pcC, '$pcC-if', '192.168.10.12', 24)],
    ),
    NetworkDevice(
      id: sw,
      type: DeviceType.switchDevice,
      name: 'Switch-Lab',
      position: const Offset(320, 200),
      interfaces: [
        NetworkInterface(id: '$sw-p1', deviceId: sw, name: 'Puerto 1'),
        NetworkInterface(id: '$sw-p2', deviceId: sw, name: 'Puerto 2'),
        NetworkInterface(id: '$sw-p3', deviceId: sw, name: 'Puerto 3'),
      ],
    ),
  ];
  final links = [
    NetworkLink(id: 'c1-l1', deviceAId: pcA, interfaceAId: '$pcA-if', deviceBId: sw, interfaceBId: '$sw-p1'),
    NetworkLink(id: 'c1-l2', deviceAId: pcB, interfaceAId: '$pcB-if', deviceBId: sw, interfaceBId: '$sw-p2'),
    NetworkLink(id: 'c1-l3', deviceAId: pcC, interfaceAId: '$pcC-if', deviceBId: sw, interfaceBId: '$sw-p3'),
  ];
  return NetworkScenario(
    id: 'case-1',
    title: 'Caso 1 — Laboratorio universitario',
    objective:
        'Configura tres equipos dentro de una misma LAN (192.168.10.0/24) conectados por un switch. '
        'Verifica que los tres puedan comunicarse entre sí usando Probar conectividad y observa el recorrido en Packet Journey. '
        'Trabaja: IPv4, máscara, switch y conectividad local.',
    devices: devices,
    links: links,
    isBuiltInCase: true,
    caseNumber: 1,
  );
}

NetworkScenario _case2DosDepartamentos() {
  const pcA = 'c2-pcA', swA = 'c2-swA', router = 'c2-router', swB = 'c2-swB', pcB = 'c2-pcB';
  final devices = [
    NetworkDevice(
      id: pcA,
      type: DeviceType.pc,
      name: 'PC-Ventas',
      position: const Offset(90, 340),
      interfaces: [_hostIface(pcA, '$pcA-if', '192.168.1.10', 24, gateway: '192.168.1.1')],
    ),
    NetworkDevice(
      id: swA,
      type: DeviceType.switchDevice,
      name: 'Switch-Ventas',
      position: const Offset(230, 340),
      interfaces: [
        NetworkInterface(id: '$swA-p1', deviceId: swA, name: 'Puerto 1'),
        NetworkInterface(id: '$swA-p2', deviceId: swA, name: 'Puerto 2'),
      ],
    ),
    NetworkDevice(
      id: router,
      type: DeviceType.router,
      name: 'Router-Central',
      position: const Offset(380, 260),
      interfaces: [
        _hostIface(router, '$router-if1', '192.168.1.1', 24),
        _hostIface(router, '$router-if2', '192.168.2.1', 24),
      ],
    ),
    NetworkDevice(
      id: swB,
      type: DeviceType.switchDevice,
      name: 'Switch-Contabilidad',
      position: const Offset(530, 340),
      interfaces: [
        NetworkInterface(id: '$swB-p1', deviceId: swB, name: 'Puerto 1'),
        NetworkInterface(id: '$swB-p2', deviceId: swB, name: 'Puerto 2'),
      ],
    ),
    NetworkDevice(
      id: pcB,
      type: DeviceType.pc,
      name: 'PC-Contabilidad',
      position: const Offset(660, 340),
      interfaces: [_hostIface(pcB, '$pcB-if', '192.168.2.10', 24, gateway: '192.168.2.1')],
    ),
  ];
  final links = [
    NetworkLink(id: 'c2-l1', deviceAId: pcA, interfaceAId: '$pcA-if', deviceBId: swA, interfaceBId: '$swA-p1'),
    NetworkLink(id: 'c2-l2', deviceAId: swA, interfaceAId: '$swA-p2', deviceBId: router, interfaceBId: '$router-if1'),
    NetworkLink(id: 'c2-l3', deviceAId: router, interfaceAId: '$router-if2', deviceBId: swB, interfaceBId: '$swB-p1'),
    NetworkLink(id: 'c2-l4', deviceAId: swB, interfaceAId: '$swB-p2', deviceBId: pcB, interfaceBId: '$pcB-if'),
  ];
  return NetworkScenario(
    id: 'case-2',
    title: 'Caso 2 — Dos departamentos',
    objective:
        'Comunica el departamento de Ventas (192.168.1.0/24) con el de Contabilidad (192.168.2.0/24) a través de un router central. '
        'Verifica que PC-Ventas y PC-Contabilidad puedan comunicarse. Trabaja: subredes, gateway y router.',
    devices: devices,
    links: links,
    isBuiltInCase: true,
    caseNumber: 2,
  );
}

NetworkScenario _case3OficinaEnCrecimiento() {
  const pcA = 'c3-pcA', pcB = 'c3-pcB', pcC = 'c3-pcC', pcD = 'c3-pcD', sw = 'c3-sw', router = 'c3-router';
  final devices = [
    NetworkDevice(
      id: router,
      type: DeviceType.router,
      name: 'Router-Oficina',
      position: const Offset(340, 200),
      interfaces: [_hostIface(router, '$router-if1', '192.168.0.1', 24)],
    ),
    NetworkDevice(
      id: sw,
      type: DeviceType.switchDevice,
      name: 'Switch-Oficina',
      position: const Offset(340, 330),
      interfaces: [
        NetworkInterface(id: '$sw-p0', deviceId: sw, name: 'Puerto 0'),
        NetworkInterface(id: '$sw-p1', deviceId: sw, name: 'Puerto 1'),
        NetworkInterface(id: '$sw-p2', deviceId: sw, name: 'Puerto 2'),
        NetworkInterface(id: '$sw-p3', deviceId: sw, name: 'Puerto 3'),
        NetworkInterface(id: '$sw-p4', deviceId: sw, name: 'Puerto 4'),
      ],
    ),
    NetworkDevice(
      id: pcA,
      type: DeviceType.pc,
      name: 'PC-Recepción',
      position: const Offset(120, 460),
      interfaces: [_hostIface(pcA, '$pcA-if', '192.168.0.10', 24, gateway: '192.168.0.1')],
    ),
    NetworkDevice(
      id: pcB,
      type: DeviceType.pc,
      name: 'PC-Ventas',
      position: const Offset(260, 500),
      interfaces: [_hostIface(pcB, '$pcB-if', '192.168.0.11', 24, gateway: '192.168.0.1')],
    ),
    NetworkDevice(
      id: pcC,
      type: DeviceType.pc,
      name: 'PC-Soporte',
      position: const Offset(420, 500),
      interfaces: [_hostIface(pcC, '$pcC-if', '192.168.0.12', 24, gateway: '192.168.0.1')],
    ),
    NetworkDevice(
      id: pcD,
      type: DeviceType.laptop,
      name: 'Laptop-Gerencia',
      position: const Offset(560, 460),
      interfaces: [_hostIface(pcD, '$pcD-if', '192.168.0.13', 24, gateway: '192.168.0.1')],
    ),
  ];
  final links = [
    NetworkLink(id: 'c3-l0', deviceAId: router, interfaceAId: '$router-if1', deviceBId: sw, interfaceBId: '$sw-p0'),
    NetworkLink(id: 'c3-l1', deviceAId: pcA, interfaceAId: '$pcA-if', deviceBId: sw, interfaceBId: '$sw-p1'),
    NetworkLink(id: 'c3-l2', deviceAId: pcB, interfaceAId: '$pcB-if', deviceBId: sw, interfaceBId: '$sw-p2'),
    NetworkLink(id: 'c3-l3', deviceAId: pcC, interfaceAId: '$pcC-if', deviceBId: sw, interfaceBId: '$sw-p3'),
    NetworkLink(id: 'c3-l4', deviceAId: pcD, interfaceAId: '$pcD-if', deviceBId: sw, interfaceBId: '$sw-p4'),
  ];
  return NetworkScenario(
    id: 'case-3',
    title: 'Caso 3 — Oficina en crecimiento',
    objective:
        'La oficina creció y la red plana 192.168.0.0/24 debe dividirse en cuatro subredes '
        '(Recepción, Ventas, Soporte, Gerencia). Usa primero el Taller de subnetting para calcular '
        'los cuatro bloques y su rango de hosts; luego regresa a esta topología y reconfigura las '
        'direcciones IPv4 de cada equipo según la subred que le corresponda. Trabaja: subnetting, rangos y planificación.',
    devices: devices,
    links: links,
    isBuiltInCase: true,
    caseNumber: 3,
  );
}

NetworkScenario _case4ServiciosDeEmpresa() {
  const server = 'c4-server', router = 'c4-router', sw = 'c4-sw', pcA = 'c4-pcA', pcB = 'c4-pcB';
  final serverDevice = NetworkDevice(
    id: server,
    type: DeviceType.server,
    name: 'Servidor-DHCP-DNS',
    position: const Offset(120, 220),
    interfaces: [_hostIface(server, '$server-if', '192.168.5.5', 24, gateway: '192.168.5.1')],
    serverRole: ServerRole.dnsAndDhcp,
    dhcpPoolStart: '192.168.5.100',
    dhcpPoolEnd: '192.168.5.150',
    dhcpPrefixLength: 24,
    dhcpGateway: '192.168.5.1',
    dhcpDns: '192.168.5.5',
    dnsRecords: {
      'portal.universidad.test': '192.168.5.5',
      'intranet.universidad.test': '192.168.5.5',
    },
  );
  final devices = [
    serverDevice,
    NetworkDevice(
      id: router,
      type: DeviceType.router,
      name: 'Router-Empresa',
      position: const Offset(320, 260),
      interfaces: [_hostIface(router, '$router-if', '192.168.5.1', 24)],
    ),
    NetworkDevice(
      id: sw,
      type: DeviceType.switchDevice,
      name: 'Switch-Empresa',
      position: const Offset(320, 400),
      interfaces: [
        NetworkInterface(id: '$sw-p0', deviceId: sw, name: 'Puerto 0'),
        NetworkInterface(id: '$sw-p1', deviceId: sw, name: 'Puerto 1'),
        NetworkInterface(id: '$sw-p2', deviceId: sw, name: 'Puerto 2'),
        NetworkInterface(id: '$sw-p3', deviceId: sw, name: 'Puerto 3'),
      ],
    ),
    NetworkDevice(
      id: pcA,
      type: DeviceType.pc,
      name: 'PC-Empleado-01',
      position: const Offset(180, 500),
      interfaces: [
        NetworkInterface(
          id: '$pcA-if',
          deviceId: pcA,
          name: 'Interfaz',
          ipv4: const Ipv4Configuration(address: '', prefixLength: 24, mode: AddressMode.dhcp),
        ),
      ],
    ),
    NetworkDevice(
      id: pcB,
      type: DeviceType.pc,
      name: 'PC-Empleado-02',
      position: const Offset(460, 500),
      interfaces: [
        NetworkInterface(
          id: '$pcB-if',
          deviceId: pcB,
          name: 'Interfaz',
          ipv4: const Ipv4Configuration(address: '', prefixLength: 24, mode: AddressMode.dhcp),
        ),
      ],
    ),
  ];
  final links = [
    NetworkLink(id: 'c4-l0', deviceAId: server, interfaceAId: '$server-if', deviceBId: router, interfaceBId: '$router-if'),
    NetworkLink(id: 'c4-l1', deviceAId: router, interfaceAId: '$router-if', deviceBId: sw, interfaceBId: '$sw-p0'),
    NetworkLink(id: 'c4-l2', deviceAId: pcA, interfaceAId: '$pcA-if', deviceBId: sw, interfaceBId: '$sw-p1'),
    NetworkLink(id: 'c4-l3', deviceAId: pcB, interfaceAId: '$pcB-if', deviceBId: sw, interfaceBId: '$sw-p2'),
  ];
  return NetworkScenario(
    id: 'case-4',
    title: 'Caso 4 — Servicios de empresa',
    objective:
        'PC-Empleado-01 y PC-Empleado-02 están configurados en modo DHCP. Usa la herramienta de '
        'DHCP simulado para que reciban su configuración desde Servidor-DHCP-DNS, y luego usa DNS '
        'simulado para resolver "portal.universidad.test" desde cualquiera de los equipos. '
        'Comprende cómo los clientes reciben configuración y resuelven nombres.',
    devices: devices,
    links: links,
    isBuiltInCase: true,
    caseNumber: 4,
  );
}

NetworkScenario _case5RedConFallas() {
  const pcA = 'c5-pcA', pcB = 'c5-pcB', swA = 'c5-swA', router = 'c5-router', swB = 'c5-swB', pcC = 'c5-pcC';
  final devices = [
    NetworkDevice(
      id: pcA,
      type: DeviceType.pc,
      name: 'PC-Diseño-01',
      position: const Offset(90, 300),
      interfaces: [_hostIface(pcA, '$pcA-if', '192.168.7.10', 24, gateway: '192.168.7.1')],
    ),
    NetworkDevice(
      id: pcB,
      type: DeviceType.pc,
      name: 'PC-Diseño-02',
      position: const Offset(90, 460),
      // Falla oculta: el gateway apunta a una dirección que, aunque
      // sintácticamente pertenece a la misma subred, no existe en ningún
      // dispositivo real de la topología. PC-Diseño-02 podrá comunicarse
      // con sus compañeros de la misma LAN, pero no logrará salir hacia
      // otras redes (p. ej. Servidor-Impresión).
      interfaces: [_hostIface(pcB, '$pcB-if', '192.168.7.11', 24, gateway: '192.168.7.99')],
    ),
    NetworkDevice(
      id: swA,
      type: DeviceType.switchDevice,
      name: 'Switch-Diseño',
      position: const Offset(230, 380),
      interfaces: [
        NetworkInterface(id: '$swA-p0', deviceId: swA, name: 'Puerto 0'),
        NetworkInterface(id: '$swA-p1', deviceId: swA, name: 'Puerto 1'),
        NetworkInterface(id: '$swA-p2', deviceId: swA, name: 'Puerto 2'),
      ],
    ),
    NetworkDevice(
      id: router,
      type: DeviceType.router,
      name: 'Router-Sede',
      position: const Offset(380, 300),
      interfaces: [
        _hostIface(router, '$router-if1', '192.168.7.1', 24),
        _hostIface(router, '$router-if2', '192.168.8.1', 24),
      ],
    ),
    NetworkDevice(
      id: swB,
      type: DeviceType.switchDevice,
      name: 'Switch-Impresión',
      position: const Offset(530, 300),
      interfaces: [
        NetworkInterface(id: '$swB-p0', deviceId: swB, name: 'Puerto 0'),
        NetworkInterface(id: '$swB-p1', deviceId: swB, name: 'Puerto 1'),
      ],
    ),
    NetworkDevice(
      id: pcC,
      type: DeviceType.server,
      name: 'Servidor-Impresión',
      position: const Offset(660, 300),
      interfaces: [_hostIface(pcC, '$pcC-if', '192.168.8.10', 24, gateway: '192.168.8.1')],
    ),
  ];
  final links = [
    NetworkLink(id: 'c5-l0', deviceAId: pcA, interfaceAId: '$pcA-if', deviceBId: swA, interfaceBId: '$swA-p0'),
    NetworkLink(id: 'c5-l1', deviceAId: pcB, interfaceAId: '$pcB-if', deviceBId: swA, interfaceBId: '$swA-p1'),
    NetworkLink(id: 'c5-l2', deviceAId: swA, interfaceAId: '$swA-p2', deviceBId: router, interfaceBId: '$router-if1'),
    NetworkLink(id: 'c5-l3', deviceAId: router, interfaceAId: '$router-if2', deviceBId: swB, interfaceBId: '$swB-p0'),
    NetworkLink(id: 'c5-l4', deviceAId: swB, interfaceAId: '$swB-p1', deviceBId: pcC, interfaceBId: '$pcC-if'),
  ];
  return NetworkScenario(
    id: 'case-5',
    title: 'Caso 5 — Red con fallas',
    objective:
        'Esta red presenta una falla de conectividad. Usa Network Doctor: observa síntomas, '
        'inspecciona configuraciones, revisa el recorrido con Packet Journey, formula una '
        'hipótesis, corrige la configuración y vuelve a probar la conectividad.',
    devices: devices,
    links: links,
    isBuiltInCase: true,
    caseNumber: 5,
    testSourceDeviceId: pcB,
    testDestinationDeviceId: pcC,
    hiddenFaultDescription:
        'PC-Diseño-02 tiene configurado el gateway 192.168.7.99, una dirección que pertenece a la '
        'subred correcta pero que ningún dispositivo real de la topología posee (el router usa '
        '192.168.7.1). Por eso puede comunicarse con PC-Diseño-01 dentro de la misma LAN, pero no '
        'logra salir hacia la red de Servidor-Impresión (192.168.8.0/24).',
  );
}
