import 'enums.dart';
import 'ipv4_configuration.dart';

/// Una interfaz de red perteneciente a un [NetworkDevice].
///
/// Los hosts (PC/laptop/servidor) tienen exactamente una interfaz.
/// Los routers pueden tener varias (una por red conectada).
/// Los switches y puntos de acceso tienen "puertos" que se modelan también
/// como interfaces, pero sin configuración IPv4 propia.
class NetworkInterface {
  final String id;
  final String deviceId;
  final String name;
  Ipv4Configuration? ipv4;

  NetworkInterface({
    required this.id,
    required this.deviceId,
    required this.name,
    this.ipv4,
  });

  NetworkInterface copyWith({
    String? name,
    Ipv4Configuration? ipv4,
    bool clearIpv4 = false,
  }) {
    return NetworkInterface(
      id: id,
      deviceId: deviceId,
      name: name ?? this.name,
      ipv4: clearIpv4 ? null : (ipv4 ?? this.ipv4),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceId': deviceId,
        'name': name,
        'ipv4': ipv4?.toJson(),
      };

  factory NetworkInterface.fromJson(Map<String, dynamic> json) {
    return NetworkInterface(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      name: json['name'] as String,
      ipv4: json['ipv4'] != null
          ? Ipv4Configuration.fromJson(json['ipv4'] as Map<String, dynamic>)
          : null,
    );
  }
}
