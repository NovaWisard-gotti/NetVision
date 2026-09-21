import '../models/diagnostic_issue.dart';
import '../models/enums.dart';
import '../models/network_scenario.dart';
import 'addressing_engine.dart';

/// Motor de validación de topología y diagnóstico ("Network Doctor").
///
/// Detecta condiciones básicas configurables por el estudiante o inyectadas
/// en un caso guiado. No corrige nada automáticamente: solo informa, tal
/// como exige la regla del proyecto.
class DiagnosticsEngine {
  const DiagnosticsEngine._();

  static List<DiagnosticIssue> analyze(NetworkScenario scenario) {
    final issues = <DiagnosticIssue>[];
    final seenIps = <String, List<String>>{}; // ip -> [deviceNames]

    for (final device in scenario.devices) {
      final connected = scenario.links
          .where((l) => l.enabled && l.connects(device.id))
          .isNotEmpty;

      if (!connected && scenario.devices.length > 1) {
        issues.add(DiagnosticIssue(
          type: IssueType.isolatedDevice,
          deviceId: device.id,
          description: '${device.name} no tiene ninguna conexión activa.',
          hint: 'Conecta ${device.name} a un switch, router o punto de acceso.',
        ));
      }

      if (device.manuallyDisconnected) {
        issues.add(DiagnosticIssue(
          type: IssueType.disconnectedDevice,
          deviceId: device.id,
          description: '${device.name} está marcado como desconectado.',
          hint: 'Reactiva ${device.name} desde su panel de configuración.',
        ));
      }

      if (!device.type.supportsIpv4Configuration) continue;

      for (final iface in device.interfaces) {
        final ipv4 = iface.ipv4;
        if (ipv4 == null || ipv4.address.isEmpty) {
          issues.add(DiagnosticIssue(
            type: IssueType.incompleteConfiguration,
            deviceId: device.id,
            description: '${device.name} no tiene una dirección IPv4 configurada.',
            hint: 'Asigna una dirección IPv4 y una máscara a ${device.name}.',
          ));
          continue;
        }

        if (!AddressingEngine.isValidIpv4(ipv4.address)) {
          issues.add(DiagnosticIssue(
            type: IssueType.wrongIp,
            deviceId: device.id,
            description:
                '${device.name} tiene una dirección IPv4 con formato inválido (${ipv4.address}).',
            hint: 'Verifica que cada octeto esté entre 0 y 255.',
          ));
        } else {
          seenIps.putIfAbsent(ipv4.address, () => []).add(device.name);
        }

        if (!AddressingEngine.isValidPrefix(ipv4.prefixLength)) {
          issues.add(DiagnosticIssue(
            type: IssueType.wrongMask,
            deviceId: device.id,
            description: '${device.name} tiene un prefijo de máscara inválido.',
            hint: 'Usa un valor entre /0 y /32 (habitualmente /24 o similar).',
          ));
        }

        if (device.type != DeviceType.router) {
          final gateway = ipv4.gateway;
          if (gateway != null &&
              gateway.isNotEmpty &&
              AddressingEngine.isValidIpv4(gateway) &&
              AddressingEngine.isValidPrefix(ipv4.prefixLength)) {
            final sameNet = AddressingEngine.isWithinSubnet(
                gateway, ipv4.address, ipv4.prefixLength);
            if (!sameNet) {
              issues.add(DiagnosticIssue(
                type: IssueType.wrongGateway,
                deviceId: device.id,
                description:
                    'El gateway de ${device.name} ($gateway) no pertenece a su misma subred (${ipv4.address}/${ipv4.prefixLength}).',
                hint: 'El gateway debe estar dentro del mismo rango de red que el host.',
              ));
            }
          }
        }
      }
    }

    seenIps.forEach((ip, owners) {
      if (owners.length > 1) {
        for (final device in scenario.devices) {
          if (owners.contains(device.name)) {
            issues.add(DiagnosticIssue(
              type: IssueType.duplicateIp,
              deviceId: device.id,
              description:
                  'La dirección $ip está duplicada entre: ${owners.join(", ")}.',
              hint: 'Asigna una dirección única a cada dispositivo.',
            ));
          }
        }
      }
    });

    for (final link in scenario.links) {
      if (!link.enabled) {
        issues.add(DiagnosticIssue(
          type: IssueType.disabledLink,
          deviceId: link.deviceAId,
          description: 'Existe una conexión deshabilitada en la topología.',
          hint: 'Habilita la conexión si los dispositivos deberían comunicarse.',
        ));
      }
    }

    return issues;
  }
}
