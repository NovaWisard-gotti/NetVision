/// Una conexión (enlace) entre dos interfaces de dos dispositivos distintos.
///
/// Las conexiones de NetVision no son líneas decorativas: participan
/// directamente en la lógica del [SimulationEngine]. Si [enabled] es falso
/// o el enlace no existe, ningún paquete puede atravesarlo.
class NetworkLink {
  final String id;
  final String deviceAId;
  final String interfaceAId;
  final String deviceBId;
  final String interfaceBId;
  bool enabled;

  NetworkLink({
    required this.id,
    required this.deviceAId,
    required this.interfaceAId,
    required this.deviceBId,
    required this.interfaceBId,
    this.enabled = true,
  });

  bool connects(String deviceId) => deviceAId == deviceId || deviceBId == deviceId;

  String otherDevice(String deviceId) {
    if (deviceAId == deviceId) return deviceBId;
    if (deviceBId == deviceId) return deviceAId;
    throw ArgumentError('El dispositivo $deviceId no participa en este enlace');
  }

  String otherInterface(String interfaceId) {
    if (interfaceAId == interfaceId) return interfaceBId;
    if (interfaceBId == interfaceId) return interfaceAId;
    throw ArgumentError('La interfaz $interfaceId no participa en este enlace');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceAId': deviceAId,
        'interfaceAId': interfaceAId,
        'deviceBId': deviceBId,
        'interfaceBId': interfaceBId,
        'enabled': enabled,
      };

  factory NetworkLink.fromJson(Map<String, dynamic> json) {
    return NetworkLink(
      id: json['id'] as String,
      deviceAId: json['deviceAId'] as String,
      interfaceAId: json['interfaceAId'] as String,
      deviceBId: json['deviceBId'] as String,
      interfaceBId: json['interfaceBId'] as String,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}
