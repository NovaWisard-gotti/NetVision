/// Un salto dentro del recorrido de un paquete (Packet Journey).
class PacketHop {
  final String deviceId;
  final String deviceName;
  final String explanation;
  final bool isFailure;
  final Map<String, String> stateSnapshot; // p.ej. {'IP origen': ..., 'IP destino': ...}

  const PacketHop({
    required this.deviceId,
    required this.deviceName,
    required this.explanation,
    this.isFailure = false,
    this.stateSnapshot = const {},
  });
}

/// Resultado completo de una simulación de comunicación entre dos hosts.
class SimulatedPacket {
  final String sourceDeviceId;
  final String destinationDeviceId;
  final String sourceIp;
  final String destinationIp;
  final List<PacketHop> hops;
  final bool delivered;
  final String summary;

  const SimulatedPacket({
    required this.sourceDeviceId,
    required this.destinationDeviceId,
    required this.sourceIp,
    required this.destinationIp,
    required this.hops,
    required this.delivered,
    required this.summary,
  });
}
