import '../models/network_device.dart';
import '../models/network_scenario.dart';
import 'addressing_engine.dart';
import 'simulation_engine.dart';

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
/// dispositivo de la topología), de forma determinista y educativa. NetVision
/// no implementa DHCP Relay, así que una concesión solo puede otorgarse
/// cuando cliente y servidor comparten el mismo dominio de difusión de
/// capa 2 (ver [SimulationEngine.inSameBroadcastDomain]).
class DhcpEngine {
  const DhcpEngine._();

  /// Límite de tamaño del pool para evitar que un rango mal configurado
  /// (por ejemplo, un prefijo muy corto como /8) obligue a recorrer
  /// millones de direcciones y congele la interfaz.
  static const int _maxPoolSize = 100000;

  static List<NetworkDevice> _activeDhcpServers(NetworkScenario scenario) =>
      scenario.devices.where((d) => d.hasDhcpService && !d.manuallyDisconnected).toList();

  /// Valida la configuración de un pool DHCP de forma reutilizable, tanto
  /// para guardarlo desde la UI como para usarlo al resolver una solicitud.
  /// Devuelve `null` si es válido, o un mensaje educativo del primer
  /// problema encontrado.
  static String? validatePool({
    String? start,
    String? end,
    int? prefixLength,
    String? gateway,
    String? dns,
  }) {
    if (start == null || start.trim().isEmpty || end == null || end.trim().isEmpty) {
      return 'Indica las direcciones "Desde" y "Hasta" del pool.';
    }
    if (prefixLength == null || !AddressingEngine.isValidPrefix(prefixLength)) {
      return 'El prefijo del pool debe ser un número entre 0 y 32.';
    }
    if (!AddressingEngine.isValidIpv4(start)) {
      return 'La dirección "Desde" no es una IPv4 válida.';
    }
    if (!AddressingEngine.isValidIpv4(end)) {
      return 'La dirección "Hasta" no es una IPv4 válida.';
    }
    if (gateway == null || gateway.trim().isEmpty) {
      return 'Indica el gateway que se asignará a los clientes del pool.';
    }
    if (!AddressingEngine.isValidIpv4(gateway)) {
      return 'El gateway a asignar no es una IPv4 válida.';
    }
    if (dns != null && dns.trim().isNotEmpty && !AddressingEngine.isValidIpv4(dns)) {
      return 'El DNS a asignar no es una IPv4 válida.';
    }

    final network = AddressingEngine.networkAddress(start, prefixLength);
    if (AddressingEngine.networkAddress(end, prefixLength) != network) {
      return 'El rango "Desde/Hasta" debe pertenecer a la misma red que el prefijo indicado.';
    }

    final startInt = AddressingEngine.ipToInt(start);
    final endInt = AddressingEngine.ipToInt(end);
    if (endInt < startInt) {
      return 'La dirección "Hasta" debe ser mayor o igual que "Desde".';
    }
    if (endInt - startInt + 1 > _maxPoolSize) {
      return 'El rango del pool es demasiado grande (usa un prefijo más específico, '
          'como /24 o superior).';
    }

    final networkInt = AddressingEngine.ipToInt(network);
    final broadcastInt =
        AddressingEngine.ipToInt(AddressingEngine.broadcastAddress(start, prefixLength));
    if (startInt <= networkInt && networkInt <= endInt) {
      return 'El pool no puede incluir la dirección de red ($network).';
    }
    if (startInt <= broadcastInt && broadcastInt <= endInt) {
      return 'El pool no puede incluir la dirección de broadcast.';
    }
    final gatewayInt = AddressingEngine.ipToInt(gateway);
    if (gatewayInt >= startInt && gatewayInt <= endInt) {
      return 'El pool no puede incluir la dirección del gateway ($gateway).';
    }
    return null;
  }

  static DhcpResult requestAddress({
    required NetworkScenario scenario,
    required NetworkDevice client,
  }) {
    if (client.manuallyDisconnected) {
      return DhcpResult(
        success: false,
        message: '${client.name} está desconectado de la red y no puede solicitar DHCP.',
      );
    }

    final servers = _activeDhcpServers(scenario);
    if (servers.isEmpty) {
      return const DhcpResult(
        success: false,
        message: 'No se encontró un servidor DHCP alcanzable.',
      );
    }

    NetworkDevice? server;
    for (final candidate in servers) {
      if (SimulationEngine.inSameBroadcastDomain(
        scenario: scenario,
        deviceAId: client.id,
        deviceBId: candidate.id,
      )) {
        server = candidate;
        break;
      }
    }

    if (server == null) {
      return const DhcpResult(
        success: false,
        message: 'El servidor DHCP se encuentra en otra red y no existe DHCP Relay.',
      );
    }

    final poolError = validatePool(
      start: server.dhcpPoolStart,
      end: server.dhcpPoolEnd,
      prefixLength: server.dhcpPrefixLength,
      gateway: server.dhcpGateway,
      dns: server.dhcpDns,
    );
    if (poolError != null) {
      return DhcpResult(
        success: false,
        message: 'La configuración del pool DHCP de ${server.name} es inválida: $poolError',
      );
    }

    final start = server.dhcpPoolStart!;
    final prefix = server.dhcpPrefixLength!;
    final startInt = AddressingEngine.ipToInt(start);
    final endInt = AddressingEngine.ipToInt(server.dhcpPoolEnd!);
    final networkInt = AddressingEngine.ipToInt(AddressingEngine.networkAddress(start, prefix));
    final broadcastInt =
        AddressingEngine.ipToInt(AddressingEngine.broadcastAddress(start, prefix));
    final gatewayInt = (server.dhcpGateway != null && AddressingEngine.isValidIpv4(server.dhcpGateway!))
        ? AddressingEngine.ipToInt(server.dhcpGateway!)
        : null;

    final usedIps = <int>{};
    for (final device in scenario.devices) {
      for (final iface in device.interfaces) {
        final address = iface.ipv4?.address;
        if (address != null && address.isNotEmpty && AddressingEngine.isValidIpv4(address)) {
          usedIps.add(AddressingEngine.ipToInt(address));
        }
      }
    }

    for (var ipInt = startInt; ipInt <= endInt; ipInt++) {
      if (ipInt == networkInt || ipInt == broadcastInt) continue;
      if (gatewayInt != null && ipInt == gatewayInt) continue;
      if (usedIps.contains(ipInt)) continue;

      final candidate = AddressingEngine.intToIp(ipInt);
      return DhcpResult(
        success: true,
        assignedIp: candidate,
        prefixLength: prefix,
        gateway: server.dhcpGateway,
        dns: server.dhcpDns,
        message: '${server.name} asignó la dirección $candidate a ${client.name}.',
      );
    }

    return const DhcpResult(
      success: false,
      message: 'El pool DHCP no tiene direcciones disponibles.',
    );
  }
}
