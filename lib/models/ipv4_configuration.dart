import 'enums.dart';

/// Configuración IPv4 de una interfaz de red.
///
/// Todos los cálculos derivados (red, broadcast, rango de hosts, etc.) se
/// realizan en [AddressingEngine]; este modelo solo almacena los valores
/// crudos que el estudiante ve y edita en el panel de configuración.
class Ipv4Configuration {
  final String address;
  final int prefixLength; // 0-32, equivalente a la máscara.
  final String? gateway;
  final String? dns;
  final AddressMode mode;

  const Ipv4Configuration({
    required this.address,
    required this.prefixLength,
    this.gateway,
    this.dns,
    this.mode = AddressMode.static,
  });

  factory Ipv4Configuration.empty() => const Ipv4Configuration(
        address: '',
        prefixLength: 24,
        gateway: null,
        dns: null,
        mode: AddressMode.static,
      );

  bool get isComplete => address.trim().isNotEmpty && prefixLength >= 0;

  Ipv4Configuration copyWith({
    String? address,
    int? prefixLength,
    String? gateway,
    bool clearGateway = false,
    String? dns,
    bool clearDns = false,
    AddressMode? mode,
  }) {
    return Ipv4Configuration(
      address: address ?? this.address,
      prefixLength: prefixLength ?? this.prefixLength,
      gateway: clearGateway ? null : (gateway ?? this.gateway),
      dns: clearDns ? null : (dns ?? this.dns),
      mode: mode ?? this.mode,
    );
  }

  Map<String, dynamic> toJson() => {
        'address': address,
        'prefixLength': prefixLength,
        'gateway': gateway,
        'dns': dns,
        'mode': mode.name,
      };

  factory Ipv4Configuration.fromJson(Map<String, dynamic> json) {
    return Ipv4Configuration(
      address: json['address'] as String? ?? '',
      prefixLength: json['prefixLength'] as int? ?? 24,
      gateway: json['gateway'] as String?,
      dns: json['dns'] as String?,
      mode: AddressMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => AddressMode.static,
      ),
    );
  }
}
