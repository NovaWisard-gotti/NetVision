import '../models/enums.dart';
import '../models/network_device.dart';
import '../models/network_interface.dart';
import '../models/network_link.dart';
import '../models/network_scenario.dart';
import '../models/packet_hop.dart';
import 'addressing_engine.dart';

/// Resultado interno de una búsqueda de camino de capa 2 (a través de
/// switches / puntos de acceso) entre una interfaz de origen y una interfaz
/// de destino dentro del mismo dominio de difusión.
class _L2PathResult {
  final bool reached;
  final List<NetworkDevice> relayDevices; // switches/APs atravesados
  final String? failureReason;

  _L2PathResult.success(this.relayDevices)
      : reached = true,
        failureReason = null;
  _L2PathResult.failure(this.failureReason)
      : reached = false,
        relayDevices = const [];
}

/// Motor de simulación de comunicación entre dispositivos.
///
/// Este motor NO usa animaciones ni resultados predefinidos: cada
/// [PacketHop] se calcula a partir del estado real de la topología
/// (interfaces, IPs, máscaras, enlaces habilitados y tablas de rutas). Si un
/// dato de configuración es incorrecto, la simulación falla exactamente en
/// el punto donde fallaría en una red real.
class SimulationEngine {
  const SimulationEngine._();

  static List<NetworkLink> _activeLinks(NetworkScenario scenario) =>
      scenario.links.where((l) => l.enabled).toList();

  static List<NetworkDevice> _neighbors(
    NetworkScenario scenario,
    NetworkDevice device,
  ) {
    final links = _activeLinks(scenario).where((l) => l.connects(device.id));
    final result = <NetworkDevice>[];
    for (final link in links) {
      final otherId = link.otherDevice(device.id);
      final other = scenario.deviceById(otherId);
      if (other != null && !other.manuallyDisconnected) {
        result.add(other);
      }
    }
    return result;
  }

  /// Busca si existe un camino de capa 2 (a través de switches/APs, nunca
  /// atravesando un router) entre [from] y el dispositivo dueño de
  /// [targetIp] dentro de la misma subred. BFS clásico.
  static _L2PathResult _findLayer2Path({
    required NetworkScenario scenario,
    required NetworkDevice from,
    required String targetIp,
    required int targetPrefix,
  }) {
    final visited = <String>{from.id};
    final queue = <List<NetworkDevice>>[
      [from]
    ];
    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final current = path.last;

      // ¿El dispositivo actual posee la IP objetivo en alguna interfaz?
      if (current.id != from.id) {
        for (final iface in current.interfaces) {
          if (iface.ipv4 != null &&
              iface.ipv4!.address == targetIp &&
              !current.manuallyDisconnected) {
            return _L2PathResult.success(
              path.sublist(1, path.length - 1).where((d) => d.type.isLayer2Relay).toList(),
            );
          }
        }
      }

      for (final neighbor in _neighbors(scenario, current)) {
        if (visited.contains(neighbor.id)) continue;
        // Solo se puede seguir avanzando en L2 a través de relays (switch/AP)
        // o llegar directamente al destino. No se atraviesan routers salvo
        // que sean el destino final buscado (poco común, pero se permite
        // que el propio router responda si su interfaz coincide).
        if (neighbor.type == DeviceType.router && neighbor.id != from.id) {
          final hasTargetIp = neighbor.interfaces
              .any((i) => i.ipv4 != null && i.ipv4!.address == targetIp);
          if (!hasTargetIp) continue;
        }
        visited.add(neighbor.id);
        queue.add([...path, neighbor]);
      }
    }
    return _L2PathResult.failure(
      'No existe un camino de capa 2 (switches/puntos de acceso) hacia ese dispositivo dentro de la misma red.',
    );
  }

  /// Encuentra, dentro de los dispositivos alcanzables por capa 2 desde
  /// [from], el router (o la propia interfaz local) cuya interfaz coincide
  /// con [gatewayIp]. Devuelve el router y su interfaz, o null si no es
  /// alcanzable.
  static (NetworkDevice, NetworkInterface)? _findGatewayInterface({
    required NetworkScenario scenario,
    required NetworkDevice from,
    required String gatewayIp,
  }) {
    final visited = <String>{from.id};
    final queue = <NetworkDevice>[from];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final iface in current.interfaces) {
        if (iface.ipv4 != null && iface.ipv4!.address == gatewayIp) {
          if (current.id != from.id) return (current, iface);
        }
      }
      for (final neighbor in _neighbors(scenario, current)) {
        if (visited.contains(neighbor.id)) continue;
        if (neighbor.type == DeviceType.router) {
          final hasIp = neighbor.interfaces
              .any((i) => i.ipv4 != null && i.ipv4!.address == gatewayIp);
          if (hasIp) {
            return (neighbor, neighbor.interfaces.firstWhere(
                (i) => i.ipv4 != null && i.ipv4!.address == gatewayIp));
          }
          // No seguimos atravesando otros routers en este BFS de L2; el
          // routing entre routers se resuelve por separado con la tabla de
          // rutas.
          continue;
        }
        visited.add(neighbor.id);
        queue.add(neighbor);
      }
    }
    return null;
  }

  /// Determina, desde un router y una IP de destino, cuál interfaz de salida
  /// debe usarse: directamente conectada o mediante una entrada de la tabla
  /// de rutas. Devuelve null si no hay ruta.
  static NetworkInterface? _routeDecision({
    required NetworkDevice router,
    required String destinationIp,
  }) {
    // 1) Redes directamente conectadas.
    for (final iface in router.interfaces) {
      if (iface.ipv4 == null) continue;
      if (AddressingEngine.isWithinSubnet(
          destinationIp, iface.ipv4!.address, iface.ipv4!.prefixLength)) {
        return iface;
      }
    }
    // 2) Tabla de rutas estática simplificada.
    for (final route in router.routeTable) {
      final destNet = route['destinationNetwork'] as String?;
      final prefix = route['prefixLength'] as int?;
      final exitIfaceId = route['exitInterfaceId'] as String?;
      if (destNet == null || prefix == null || exitIfaceId == null) continue;
      if (AddressingEngine.isWithinSubnet(destinationIp, destNet, prefix)) {
        try {
          return router.interfaces.firstWhere((i) => i.id == exitIfaceId);
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  /// Simula el envío de un paquete entre [sourceDeviceId] y
  /// [destinationDeviceId], devolviendo la secuencia completa de saltos.
  static SimulatedPacket simulate({
    required NetworkScenario scenario,
    required String sourceDeviceId,
    required String destinationDeviceId,
  }) {
    final source = scenario.deviceById(sourceDeviceId);
    final destination = scenario.deviceById(destinationDeviceId);
    final hops = <PacketHop>[];

    if (source == null || destination == null) {
      return SimulatedPacket(
        sourceDeviceId: sourceDeviceId,
        destinationDeviceId: destinationDeviceId,
        sourceIp: '',
        destinationIp: '',
        hops: const [],
        delivered: false,
        summary: 'Dispositivo de origen o destino no encontrado.',
      );
    }

    final sourceIface = source.primaryInterface;
    final destIface = destination.primaryInterface;
    final sourceIp = sourceIface?.ipv4?.address ?? '';
    final destinationIp = destIface?.ipv4?.address ?? '';

    if (source.manuallyDisconnected) {
      hops.add(PacketHop(
        deviceId: source.id,
        deviceName: source.name,
        explanation:
            '${source.name} está desconectado de la red y no puede iniciar la comunicación.',
        isFailure: true,
      ));
      return SimulatedPacket(
        sourceDeviceId: sourceDeviceId,
        destinationDeviceId: destinationDeviceId,
        sourceIp: sourceIp,
        destinationIp: destinationIp,
        hops: hops,
        delivered: false,
        summary: 'El origen está desconectado.',
      );
    }

    if (sourceIface?.ipv4 == null || !sourceIface!.ipv4!.isComplete) {
      hops.add(PacketHop(
        deviceId: source.id,
        deviceName: source.name,
        explanation:
            '${source.name} no tiene una configuración IPv4 completa y no puede enviar paquetes.',
        isFailure: true,
      ));
      return SimulatedPacket(
        sourceDeviceId: sourceDeviceId,
        destinationDeviceId: destinationDeviceId,
        sourceIp: sourceIp,
        destinationIp: destinationIp,
        hops: hops,
        delivered: false,
        summary: 'Configuración de origen incompleta.',
      );
    }

    if (destIface?.ipv4 == null || destinationIp.isEmpty) {
      hops.add(PacketHop(
        deviceId: source.id,
        deviceName: source.name,
        explanation:
            'El destino (${destination.name}) no tiene una dirección IPv4 configurada.',
        isFailure: true,
      ));
      return SimulatedPacket(
        sourceDeviceId: sourceDeviceId,
        destinationDeviceId: destinationDeviceId,
        sourceIp: sourceIp,
        destinationIp: destinationIp,
        hops: hops,
        delivered: false,
        summary: 'El destino no tiene IP configurada.',
      );
    }

    // A partir de este punto ya se validó que ambas interfaces tienen IPv4
    // completo, así que se fija una referencia no anulable para el resto
    // del método.
    final destIfaceNN = destIface!;

    hops.add(PacketHop(
      deviceId: source.id,
      deviceName: source.name,
      explanation:
          '${source.name} prepara el envío desde $sourceIp hacia $destinationIp.',
      stateSnapshot: {'IP origen': sourceIp, 'IP destino': destinationIp},
    ));

    final sameSubnet = AddressingEngine.sameSubnet(
      sourceIp,
      sourceIface.ipv4!.prefixLength,
      destinationIp,
      destIfaceNN.ipv4!.prefixLength,
    );

    if (sameSubnet) {
      hops.add(PacketHop(
        deviceId: source.id,
        deviceName: source.name,
        explanation:
            '${source.name} determina que $destinationIp pertenece a su misma red local, por lo que no necesita un router.',
      ));
      hops.add(PacketHop(
        deviceId: source.id,
        deviceName: source.name,
        explanation:
            '${source.name} resuelve la dirección física (MAC) del destino mediante ARP dentro de la red local.',
      ));

      final l2 = _findLayer2Path(
        scenario: scenario,
        from: source,
        targetIp: destinationIp,
        targetPrefix: destIfaceNN.ipv4!.prefixLength,
      );

      if (!l2.reached) {
        hops.add(PacketHop(
          deviceId: source.id,
          deviceName: source.name,
          explanation: l2.failureReason ??
              'No fue posible encontrar un camino físico hacia el destino.',
          isFailure: true,
        ));
        return SimulatedPacket(
          sourceDeviceId: sourceDeviceId,
          destinationDeviceId: destinationDeviceId,
          sourceIp: sourceIp,
          destinationIp: destinationIp,
          hops: hops,
          delivered: false,
          summary: 'No se encontró un camino local hacia el destino.',
        );
      }

      for (final relay in l2.relayDevices) {
        hops.add(PacketHop(
          deviceId: relay.id,
          deviceName: relay.name,
          explanation:
              '${relay.name} reenvía la trama hacia el puerto donde está conectado el destino.',
        ));
      }

      hops.add(PacketHop(
        deviceId: destination.id,
        deviceName: destination.name,
        explanation:
            '${destination.name} recibe el paquete correctamente en $destinationIp.',
      ));

      return SimulatedPacket(
        sourceDeviceId: sourceDeviceId,
        destinationDeviceId: destinationDeviceId,
        sourceIp: sourceIp,
        destinationIp: destinationIp,
        hops: hops,
        delivered: true,
        summary: 'Comunicación exitosa dentro de la misma red local.',
      );
    }

    // Redes diferentes: se requiere gateway.
    final gatewayIp = sourceIface.ipv4!.gateway;
    hops.add(PacketHop(
      deviceId: source.id,
      deviceName: source.name,
      explanation:
          '${source.name} determina que $destinationIp pertenece a otra red y debe enviar el paquete a su gateway configurado.',
    ));

    if (gatewayIp == null || gatewayIp.isEmpty) {
      hops.add(PacketHop(
        deviceId: source.id,
        deviceName: source.name,
        explanation:
            '${source.name} no tiene un gateway configurado, por lo que no puede salir de su red local.',
        isFailure: true,
      ));
      return SimulatedPacket(
        sourceDeviceId: sourceDeviceId,
        destinationDeviceId: destinationDeviceId,
        sourceIp: sourceIp,
        destinationIp: destinationIp,
        hops: hops,
        delivered: false,
        summary: 'Falta el gateway en el origen.',
      );
    }

    final gatewayResult = _findGatewayInterface(
      scenario: scenario,
      from: source,
      gatewayIp: gatewayIp,
    );

    if (gatewayResult == null) {
      hops.add(PacketHop(
        deviceId: source.id,
        deviceName: source.name,
        explanation:
            '${source.name} no logra alcanzar el gateway $gatewayIp. Puede que el gateway esté mal escrito, en otra red, o el enlace esté desconectado.',
        isFailure: true,
      ));
      return SimulatedPacket(
        sourceDeviceId: sourceDeviceId,
        destinationDeviceId: destinationDeviceId,
        sourceIp: sourceIp,
        destinationIp: destinationIp,
        hops: hops,
        delivered: false,
        summary: 'El gateway configurado no es alcanzable.',
      );
    }

    var currentRouter = gatewayResult.$1;
    hops.add(PacketHop(
      deviceId: currentRouter.id,
      deviceName: currentRouter.name,
      explanation:
          'El paquete llega al router ${currentRouter.name} a través de su interfaz $gatewayIp.',
    ));

    // Permite hasta 4 saltos entre routers (suficiente para el alcance del
    // MVP) para evitar bucles infinitos en topologías mal formadas.
    var hopsBudget = 4;
    while (true) {
      if (hopsBudget-- <= 0) {
        hops.add(PacketHop(
          deviceId: currentRouter.id,
          deviceName: currentRouter.name,
          explanation:
              'Se alcanzó el límite de saltos entre routers sin llegar al destino. Revisa la tabla de rutas.',
          isFailure: true,
        ));
        return SimulatedPacket(
          sourceDeviceId: sourceDeviceId,
          destinationDeviceId: destinationDeviceId,
          sourceIp: sourceIp,
          destinationIp: destinationIp,
          hops: hops,
          delivered: false,
          summary: 'Demasiados saltos entre routers sin resolver la ruta.',
        );
      }

      final exitIface = _routeDecision(
        router: currentRouter,
        destinationIp: destinationIp,
      );

      if (exitIface == null) {
        hops.add(PacketHop(
          deviceId: currentRouter.id,
          deviceName: currentRouter.name,
          explanation:
              'El router ${currentRouter.name} no encuentra una ruta válida hacia la red de destino ($destinationIp).',
          isFailure: true,
        ));
        return SimulatedPacket(
          sourceDeviceId: sourceDeviceId,
          destinationDeviceId: destinationDeviceId,
          sourceIp: sourceIp,
          destinationIp: destinationIp,
          hops: hops,
          delivered: false,
          summary: 'Ruta faltante en ${currentRouter.name}.',
        );
      }

      final isDirectlyConnected = AddressingEngine.isWithinSubnet(
        destinationIp,
        exitIface.ipv4!.address,
        exitIface.ipv4!.prefixLength,
      );

      if (isDirectlyConnected) {
        hops.add(PacketHop(
          deviceId: currentRouter.id,
          deviceName: currentRouter.name,
          explanation:
              '${currentRouter.name} reconoce que la red de destino está directamente conectada a su interfaz ${exitIface.name} y reenvía el paquete por esa red.',
        ));

        final l2 = _findLayer2Path(
          scenario: scenario,
          from: currentRouter,
          targetIp: destinationIp,
          targetPrefix: destIfaceNN.ipv4!.prefixLength,
        );

        if (!l2.reached) {
          hops.add(PacketHop(
            deviceId: currentRouter.id,
            deviceName: currentRouter.name,
            explanation: l2.failureReason ??
                'No se encontró un camino físico hacia el destino desde este router.',
            isFailure: true,
          ));
          return SimulatedPacket(
            sourceDeviceId: sourceDeviceId,
            destinationDeviceId: destinationDeviceId,
            sourceIp: sourceIp,
            destinationIp: destinationIp,
            hops: hops,
            delivered: false,
            summary: 'El destino no es alcanzable físicamente desde el router.',
          );
        }

        for (final relay in l2.relayDevices) {
          hops.add(PacketHop(
            deviceId: relay.id,
            deviceName: relay.name,
            explanation:
                '${relay.name} reenvía la trama hacia el puerto donde está conectado el destino.',
          ));
        }

        hops.add(PacketHop(
          deviceId: destination.id,
          deviceName: destination.name,
          explanation:
              '${destination.name} recibe el paquete correctamente en $destinationIp.',
        ));

        return SimulatedPacket(
          sourceDeviceId: sourceDeviceId,
          destinationDeviceId: destinationDeviceId,
          sourceIp: sourceIp,
          destinationIp: destinationIp,
          hops: hops,
          delivered: true,
          summary: 'Comunicación exitosa entre redes distintas.',
        );
      } else {
        // Hay que saltar a otro router a través de exitIface. Buscamos, en
        // el otro extremo del enlace de exitIface, otro router.
        final link = _activeLinks(scenario).firstWhere(
          (l) =>
              (l.interfaceAId == exitIface.id) ||
              (l.interfaceBId == exitIface.id),
          orElse: () => NetworkLink(
              id: '',
              deviceAId: '',
              interfaceAId: '',
              deviceBId: '',
              interfaceBId: ''),
        );
        if (link.id.isEmpty) {
          hops.add(PacketHop(
            deviceId: currentRouter.id,
            deviceName: currentRouter.name,
            explanation:
                'La interfaz de salida de ${currentRouter.name} no tiene una conexión activa.',
            isFailure: true,
          ));
          return SimulatedPacket(
            sourceDeviceId: sourceDeviceId,
            destinationDeviceId: destinationDeviceId,
            sourceIp: sourceIp,
            destinationIp: destinationIp,
            hops: hops,
            delivered: false,
            summary: 'Interfaz de salida sin conexión.',
          );
        }
        final nextDeviceId = link.otherDevice(currentRouter.id);
        final nextDevice = scenario.deviceById(nextDeviceId);
        if (nextDevice == null || nextDevice.type != DeviceType.router) {
          hops.add(PacketHop(
            deviceId: currentRouter.id,
            deviceName: currentRouter.name,
            explanation:
                'La ruta configurada en ${currentRouter.name} no conduce a otro router válido.',
            isFailure: true,
          ));
          return SimulatedPacket(
            sourceDeviceId: sourceDeviceId,
            destinationDeviceId: destinationDeviceId,
            sourceIp: sourceIp,
            destinationIp: destinationIp,
            hops: hops,
            delivered: false,
            summary: 'Ruta inválida.',
          );
        }
        hops.add(PacketHop(
          deviceId: nextDevice.id,
          deviceName: nextDevice.name,
          explanation:
              'El paquete continúa hacia el router ${nextDevice.name} según la tabla de rutas.',
        ));
        currentRouter = nextDevice;
      }
    }
  }
}
