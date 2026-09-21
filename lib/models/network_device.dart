import 'dart:ui';
import 'enums.dart';
import 'network_interface.dart';

/// Un dispositivo dentro del NetVision Workspace.
class NetworkDevice {
  final String id;
  final DeviceType type;
  String name;
  Offset position;
  List<NetworkInterface> interfaces;

  /// Solo aplica a servidores: qué servicio simulado presta.
  ServerRole serverRole;

  /// Pool DHCP simulado, solo relevante si serverRole incluye dhcp.
  String? dhcpPoolStart;
  String? dhcpPoolEnd;
  int? dhcpPrefixLength;
  String? dhcpGateway;
  String? dhcpDns;

  /// Registros DNS simulados: hostname -> ip. Solo relevante si serverRole
  /// incluye dns.
  Map<String, String> dnsRecords;

  /// Tabla de rutas simplificada, solo relevante para routers.
  /// Cada entrada: {destinationNetwork, prefixLength, exitInterfaceId}
  List<Map<String, dynamic>> routeTable;

  /// Si el dispositivo está manualmente "apagado"/desconectado por el
  /// estudiante o por un escenario de Network Doctor.
  bool manuallyDisconnected;

  NetworkDevice({
    required this.id,
    required this.type,
    required this.name,
    required this.position,
    List<NetworkInterface>? interfaces,
    this.serverRole = ServerRole.none,
    this.dhcpPoolStart,
    this.dhcpPoolEnd,
    this.dhcpPrefixLength,
    this.dhcpGateway,
    this.dhcpDns,
    Map<String, String>? dnsRecords,
    List<Map<String, dynamic>>? routeTable,
    this.manuallyDisconnected = false,
  })  : interfaces = interfaces ?? [],
        dnsRecords = dnsRecords ?? {},
        routeTable = routeTable ?? [];

  bool get hasDhcpService =>
      serverRole == ServerRole.dhcp || serverRole == ServerRole.dnsAndDhcp;
  bool get hasDnsService =>
      serverRole == ServerRole.dns || serverRole == ServerRole.dnsAndDhcp;

  NetworkInterface? get primaryInterface =>
      interfaces.isNotEmpty ? interfaces.first : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'x': position.dx,
        'y': position.dy,
        'interfaces': interfaces.map((i) => i.toJson()).toList(),
        'serverRole': serverRole.name,
        'dhcpPoolStart': dhcpPoolStart,
        'dhcpPoolEnd': dhcpPoolEnd,
        'dhcpPrefixLength': dhcpPrefixLength,
        'dhcpGateway': dhcpGateway,
        'dhcpDns': dhcpDns,
        'dnsRecords': dnsRecords,
        'routeTable': routeTable,
        'manuallyDisconnected': manuallyDisconnected,
      };

  factory NetworkDevice.fromJson(Map<String, dynamic> json) {
    return NetworkDevice(
      id: json['id'] as String,
      type: DeviceType.values.firstWhere((t) => t.name == json['type']),
      name: json['name'] as String,
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      interfaces: (json['interfaces'] as List<dynamic>? ?? [])
          .map((e) => NetworkInterface.fromJson(e as Map<String, dynamic>))
          .toList(),
      serverRole: ServerRole.values.firstWhere(
        (r) => r.name == json['serverRole'],
        orElse: () => ServerRole.none,
      ),
      dhcpPoolStart: json['dhcpPoolStart'] as String?,
      dhcpPoolEnd: json['dhcpPoolEnd'] as String?,
      dhcpPrefixLength: json['dhcpPrefixLength'] as int?,
      dhcpGateway: json['dhcpGateway'] as String?,
      dhcpDns: json['dhcpDns'] as String?,
      dnsRecords: Map<String, String>.from(
          (json['dnsRecords'] as Map<dynamic, dynamic>? ?? {})),
      routeTable: (json['routeTable'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      manuallyDisconnected: json['manuallyDisconnected'] as bool? ?? false,
    );
  }
}
