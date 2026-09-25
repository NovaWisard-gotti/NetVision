import '../models/diagnostic_issue.dart';
import '../models/enums.dart';
import '../models/network_device.dart';
import '../models/network_scenario.dart';
import 'addressing_engine.dart';
import 'simulation_engine.dart';

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

    issues.addAll(_detectIncompatibleSubnets(scenario));
    issues.addAll(_detectMissingRoutes(scenario));
    issues.addAll(_detectWrongDns(scenario));

    return issues;
  }

  /// Detecta dispositivos que, perteneciendo al mismo segmento de capa 2
  /// (deberían poder comunicarse directamente, sin router), están
  /// configurados en subredes incompatibles según sus máscaras reales.
  static List<DiagnosticIssue> _detectIncompatibleSubnets(NetworkScenario scenario) {
    final issues = <DiagnosticIssue>[];
    for (final segment in SimulationEngine.l2Segments(scenario)) {
      final entries = <(NetworkDevice, String, int)>[];
      for (final device in scenario.devices) {
        if (!device.type.supportsIpv4Configuration) continue;
        for (final iface in device.interfaces) {
          if (!segment.contains('${device.id}::${iface.id}')) continue;
          final ipv4 = iface.ipv4;
          if (ipv4 == null || ipv4.address.isEmpty) continue;
          if (!AddressingEngine.isValidIpv4(ipv4.address) ||
              !AddressingEngine.isValidPrefix(ipv4.prefixLength)) {
            continue;
          }
          entries.add((device, ipv4.address, ipv4.prefixLength));
        }
      }

      for (var i = 0; i < entries.length; i++) {
        for (var j = i + 1; j < entries.length; j++) {
          final a = entries[i];
          final b = entries[j];
          final compatible =
              AddressingEngine.sameSubnet(a.$2, a.$3, b.$2, b.$3);
          if (!compatible) {
            issues.add(DiagnosticIssue(
              type: IssueType.incompatibleSubnets,
              deviceId: a.$1.id,
              description:
                  '${a.$1.name} (${a.$2}/${a.$3}) y ${b.$1.name} (${b.$2}/${b.$3}) comparten la misma '
                  'red física pero están configurados en subredes incompatibles.',
              hint: 'Ajusta la dirección o el prefijo para que ambos equipos pertenezcan a la misma red.',
            ));
          }
        }
      }
    }
    return issues;
  }

  /// Busca, desde cada dispositivo, todos los demás dispositivos alcanzables
  /// por cualquier enlace activo (sin restricción de capa), ignorando si el
  /// enrutamiento realmente funciona. Se usa para decidir si una red remota
  /// es físicamente alcanzable desde un router y, por lo tanto, si a ese
  /// router le hace falta una ruta hacia ella.
  static Set<String> _physicallyReachableDevices(NetworkScenario scenario, String startId) {
    final visited = <String>{startId};
    final queue = <String>[startId];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentDevice = scenario.deviceById(current);
      if (currentDevice == null || currentDevice.manuallyDisconnected) continue;
      for (final link in scenario.links) {
        if (!link.enabled || !link.connects(current)) continue;
        final otherId = link.otherDevice(current);
        final other = scenario.deviceById(otherId);
        if (other == null || other.manuallyDisconnected) continue;
        if (visited.add(otherId)) queue.add(otherId);
      }
    }
    visited.remove(startId);
    return visited;
  }

  /// Detecta routers a los que les falta una ruta (directamente conectada o
  /// estática) hacia una red que existe en la topología y que es físicamente
  /// alcanzable desde ese router. Al evaluar cada router de forma
  /// independiente, también detecta rutas de retorno faltantes.
  static List<DiagnosticIssue> _detectMissingRoutes(NetworkScenario scenario) {
    final issues = <DiagnosticIssue>[];

    // Redes existentes en la topología: "network/prefix" -> dispositivos que la poseen.
    final networkOwners = <String, List<String>>{};
    for (final device in scenario.devices) {
      if (!device.type.supportsIpv4Configuration) continue;
      for (final iface in device.interfaces) {
        final ipv4 = iface.ipv4;
        if (ipv4 == null || ipv4.address.isEmpty) continue;
        if (!AddressingEngine.isValidIpv4(ipv4.address) ||
            !AddressingEngine.isValidPrefix(ipv4.prefixLength)) {
          continue;
        }
        final net = AddressingEngine.networkAddress(ipv4.address, ipv4.prefixLength);
        networkOwners.putIfAbsent('$net/${ipv4.prefixLength}', () => []).add(device.id);
      }
    }

    for (final router in scenario.devices.where((d) => d.type == DeviceType.router)) {
      if (router.manuallyDisconnected) continue;
      final reachable = _physicallyReachableDevices(scenario, router.id);

      final directNetworks = <String>{};
      for (final iface in router.interfaces) {
        final ipv4 = iface.ipv4;
        if (ipv4 == null || ipv4.address.isEmpty) continue;
        if (!AddressingEngine.isValidIpv4(ipv4.address) ||
            !AddressingEngine.isValidPrefix(ipv4.prefixLength)) {
          continue;
        }
        directNetworks
            .add('${AddressingEngine.networkAddress(ipv4.address, ipv4.prefixLength)}/${ipv4.prefixLength}');
      }

      for (final entry in networkOwners.entries) {
        if (directNetworks.contains(entry.key)) continue;
        final ownedByReachableDevice = entry.value.any(reachable.contains);
        if (!ownedByReachableDevice) continue;

        final parts = entry.key.split('/');
        final destNet = parts[0];
        final destPrefix = int.parse(parts[1]);
        final hasRoute = router.routeTable.any((route) {
          final routeNet = route['destinationNetwork'] as String?;
          final routePrefix = route['prefixLength'] as int?;
          if (routeNet == null || routePrefix == null) return false;
          if (!AddressingEngine.isValidIpv4(routeNet) ||
              !AddressingEngine.isValidPrefix(routePrefix)) {
            return false;
          }
          return AddressingEngine.networkAddress(routeNet, routePrefix) == destNet &&
              routePrefix == destPrefix;
        });

        if (!hasRoute) {
          issues.add(DiagnosticIssue(
            type: IssueType.missingRoute,
            deviceId: router.id,
            description:
                '${router.name} no tiene una ruta hacia la red $destNet/$destPrefix, aunque existe '
                'un camino físico hasta ella.',
            hint: 'Agrega una ruta estática en ${router.name} hacia $destNet/$destPrefix a través de '
                'la interfaz correspondiente.',
          ));
        }
      }
    }

    return issues;
  }

  /// Detecta configuraciones DNS incorrectas: formato inválido, apuntando a
  /// un dispositivo inexistente, a uno que no presta el servicio DNS, o no
  /// alcanzable desde el cliente. Un DNS vacío no se reporta aquí porque su
  /// obligatoriedad depende del caso/ejercicio, no de la topología en sí.
  static List<DiagnosticIssue> _detectWrongDns(NetworkScenario scenario) {
    final issues = <DiagnosticIssue>[];
    for (final device in scenario.devices) {
      if (!device.type.supportsIpv4Configuration) continue;
      for (final iface in device.interfaces) {
        final dns = iface.ipv4?.dns;
        if (dns == null || dns.isEmpty) continue;

        if (!AddressingEngine.isValidIpv4(dns)) {
          issues.add(DiagnosticIssue(
            type: IssueType.wrongDns,
            deviceId: device.id,
            description: '${device.name} tiene configurado un DNS con formato inválido ($dns).',
            hint: 'Usa una dirección IPv4 válida para el DNS.',
          ));
          continue;
        }

        NetworkDevice? owner;
        for (final candidate in scenario.devices) {
          if (candidate.interfaces.any((i) => i.ipv4?.address == dns)) {
            owner = candidate;
            break;
          }
        }
        if (owner == null) {
          issues.add(DiagnosticIssue(
            type: IssueType.wrongDns,
            deviceId: device.id,
            description:
                '${device.name} tiene configurado un DNS ($dns) que no corresponde a ningún '
                'dispositivo de la topología.',
            hint: 'Verifica la dirección del servidor DNS o configura el servicio en el dispositivo correcto.',
          ));
          continue;
        }
        if (!owner.hasDnsService) {
          issues.add(DiagnosticIssue(
            type: IssueType.wrongDns,
            deviceId: device.id,
            description:
                '${device.name} tiene configurado como DNS a ${owner.name}, que no presta el servicio DNS.',
            hint: 'Activa el servicio DNS en ${owner.name} o apunta a un servidor que sí lo preste.',
          ));
          continue;
        }
        if (owner.manuallyDisconnected ||
            !SimulationEngine.inSameBroadcastDomain(
                scenario: scenario, deviceAId: device.id, deviceBId: owner.id)) {
          issues.add(DiagnosticIssue(
            type: IssueType.wrongDns,
            deviceId: device.id,
            description:
                '${device.name} no puede alcanzar a su servidor DNS configurado (${owner.name}): '
                'están en redes distintas y no existe DNS Relay.',
            hint: 'Usa un servidor DNS dentro de la misma red local, o revisa la conectividad hacia ${owner.name}.',
          ));
        }
      }
    }
    return issues;
  }
}
