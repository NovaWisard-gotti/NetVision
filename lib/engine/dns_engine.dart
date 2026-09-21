import '../models/network_device.dart';
import '../models/network_scenario.dart';

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
/// propio escenario (nunca realiza consultas externas reales).
class DnsEngine {
  const DnsEngine._();

  static NetworkDevice? findDnsServer(NetworkScenario scenario, {String? preferredIp}) {
    if (preferredIp != null) {
      for (final d in scenario.devices) {
        if (d.hasDnsService && !d.manuallyDisconnected) {
          final iface = d.primaryInterface;
          if (iface?.ipv4?.address == preferredIp) return d;
        }
      }
    }
    for (final d in scenario.devices) {
      if (d.hasDnsService && !d.manuallyDisconnected) return d;
    }
    return null;
  }

  static DnsResult resolve({
    required NetworkScenario scenario,
    required String hostname,
    String? clientDnsIp,
  }) {
    final server = findDnsServer(scenario, preferredIp: clientDnsIp);
    if (server == null) {
      return const DnsResult(
        success: false,
        message: 'No hay un servidor DNS activo y alcanzable en la topología.',
      );
    }

    if (clientDnsIp != null && clientDnsIp.isNotEmpty) {
      final serverIp = server.primaryInterface?.ipv4?.address;
      if (serverIp != clientDnsIp) {
        return DnsResult(
          success: false,
          message:
              'El cliente tiene configurado un DNS ($clientDnsIp) distinto del servidor disponible (${serverIp ?? "desconocido"}).',
        );
      }
    }

    final ip = server.dnsRecords[hostname.trim().toLowerCase()];
    if (ip == null) {
      return DnsResult(
        success: false,
        message:
            '${server.name} no tiene un registro para "$hostname". Verifica el nombre o registra el dominio en el servidor.',
      );
    }

    return DnsResult(
      success: true,
      resolvedIp: ip,
      message: '${server.name} resolvió "$hostname" hacia $ip.',
    );
  }
}
