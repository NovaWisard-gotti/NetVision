import '../models/network_device.dart';
import '../models/network_scenario.dart';
import 'addressing_engine.dart';

/// Resultado de una solicitud DHCP simulada.
class DhcpResult {
  final bool success;
  final String? assignedIp;
  final int? prefixLength;
  final String? gateway;
  final String? dns;
  final String message;

  const DhcpResult({
    required this.success,
    required this.message,
    this.assignedIp,
    this.prefixLength,
    this.gateway,
    this.dns,
  });
}

/// Motor de asignación DHCP simulada.
///
/// No implementa un servidor DHCP real: recorre el pool configurado en el
/// servidor y entrega la primera dirección libre (no usada por ningún otro
/// dispositivo de la topología), de forma determinista y educativa.
class DhcpEngine {
  const DhcpEngine._();

  static NetworkDevice? findDhcpServer(NetworkScenario scenario) {
    for (final d in scenario.devices) {
      if (d.hasDhcpService && !d.manuallyDisconnected) return d;
    }
    return null;
  }

  static DhcpResult requestAddress({
    required NetworkScenario scenario,
    required NetworkDevice client,
  }) {
    final server = findDhcpServer(scenario);
    if (server == null) {
      return const DhcpResult(
        success: false,
        message:
            'No se encontró ningún servidor DHCP activo y alcanzable en la topología.',
      );
    }

    final start = server.dhcpPoolStart;
    final end = server.dhcpPoolEnd;
    final prefix = server.dhcpPrefixLength;
    if (start == null || end == null || prefix == null) {
      return DhcpResult(
        success: false,
        message:
            'El servidor ${server.name} no tiene un pool DHCP configurado correctamente.',
      );
    }

    if (!AddressingEngine.isValidIpv4(start) ||
        !AddressingEngine.isValidIpv4(end)) {
      return const DhcpResult(
        success: false,
        message: 'El rango del pool DHCP contiene direcciones inválidas.',
      );
    }

    final startInt = AddressingEngine.ipToInt(start);
    final endInt = AddressingEngine.ipToInt(end);
    if (endInt < startInt) {
      return const DhcpResult(
        success: false,
        message: 'El rango del pool DHCP es inválido (fin antes que inicio).',
      );
    }

    final usedIps = <String>{};
    for (final device in scenario.devices) {
      for (final iface in device.interfaces) {
        if (iface.ipv4 != null && iface.ipv4!.address.isNotEmpty) {
          usedIps.add(iface.ipv4!.address);
        }
      }
    }

    for (var ipInt = startInt; ipInt <= endInt; ipInt++) {
      final candidate = AddressingEngine.intToIp(ipInt);
      if (!usedIps.contains(candidate)) {
        return DhcpResult(
          success: true,
          assignedIp: candidate,
          prefixLength: prefix,
          gateway: server.dhcpGateway,
          dns: server.dhcpDns,
          message:
              '${server.name} asignó la dirección $candidate a ${client.name}.',
        );
      }
    }

    return DhcpResult(
      success: false,
      message:
          'El pool DHCP de ${server.name} está agotado: no quedan direcciones libres.',
    );
  }
}
