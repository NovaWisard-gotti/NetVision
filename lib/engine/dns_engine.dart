import '../models/network_device.dart';
import '../models/network_scenario.dart';
import 'addressing_engine.dart';
import 'simulation_engine.dart';

/// Resultado de una consulta DNS simulada.
class DnsResult {
  final bool success;
  final String? resolvedIp;
  final String message;

  const DnsResult({
    required this.success,
    required this.message,
    this.resolvedIp,
  });
}

/// Motor de resolución DNS simulada.
///
/// Trabaja sobre un mapa hostname -> IP almacenado en el servidor DNS de la
/// topología. Únicamente resuelve nombres dentro de dominios ficticios del
/// propio escenario (nunca realiza consultas externas reales). Nunca elige
/// automáticamente un servidor DNS: el cliente debe tener configurada
/// explícitamente la dirección de un servidor DNS real y alcanzable.
class DnsEngine {
  const DnsEngine._();

  static DnsResult resolve({
    required NetworkScenario scenario,
    required String hostname,
    required String clientDeviceId,
    String? clientDnsIp,
  }) {
    if (clientDnsIp == null || clientDnsIp.trim().isEmpty) {
      return const DnsResult(
        success: false,
        message: 'El dispositivo no tiene configurado un servidor DNS.',
      );
    }
    final dnsIp = clientDnsIp.trim();
    if (!AddressingEngine.isValidIpv4(dnsIp)) {
      return const DnsResult(
        success: false,
        message: 'La dirección DNS configurada no tiene un formato válido.',
      );
    }

    NetworkDevice? server;
    for (final device in scenario.devices) {
      if (device.interfaces.any((i) => i.ipv4?.address == dnsIp)) {
        server = device;
        break;
      }
    }
    if (server == null) {
      return const DnsResult(
        success: false,
        message: 'El servidor DNS configurado no existe en la topología.',
      );
    }
    if (!server.hasDnsService) {
      return DnsResult(
        success: false,
        message: 'La dirección DNS configurada ($dnsIp) no corresponde a un servidor DNS.',
      );
    }
    if (server.manuallyDisconnected ||
        !SimulationEngine.inSameBroadcastDomain(
          scenario: scenario,
          deviceAId: clientDeviceId,
          deviceBId: server.id,
        )) {
      return DnsResult(
        success: false,
        message: 'El servidor DNS configurado no es alcanzable desde este dispositivo.',
      );
    }

    final ip = server.dnsRecords[hostname.trim().toLowerCase()];
    if (ip == null) {
      return const DnsResult(
        success: false,
        message: 'No se encontró un registro DNS para el dominio solicitado.',
      );
    }

    return DnsResult(
      success: true,
      resolvedIp: ip,
      message: '${server.name} resolvió "$hostname" hacia $ip.',
    );
  }
}
