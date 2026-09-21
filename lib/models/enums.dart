/// Tipos de dispositivo soportados en el MVP de NetVision.
enum DeviceType { pc, laptop, server, switchDevice, router, accessPoint }

extension DeviceTypeX on DeviceType {
  String get label {
    switch (this) {
      case DeviceType.pc:
        return 'PC';
      case DeviceType.laptop:
        return 'Laptop';
      case DeviceType.server:
        return 'Servidor';
      case DeviceType.switchDevice:
        return 'Switch';
      case DeviceType.router:
        return 'Router';
      case DeviceType.accessPoint:
        return 'Punto de acceso';
    }
  }

  /// Solo los dispositivos "de host" o router tienen direccionamiento IPv4
  /// configurable. Los switches y puntos de acceso operan en capa 2 dentro
  /// del alcance del MVP.
  bool get supportsIpv4Configuration =>
      this == DeviceType.pc ||
      this == DeviceType.laptop ||
      this == DeviceType.server ||
      this == DeviceType.router;

  /// Un router puede tener más de una interfaz (una por red conectada).
  bool get isMultiInterface => this == DeviceType.router;

  bool get isLayer2Relay =>
      this == DeviceType.switchDevice || this == DeviceType.accessPoint;
}

/// Modo de asignación de dirección IPv4 de un host.
enum AddressMode { static, dhcp }

/// Rol de servicio simulado que puede cumplir un servidor.
enum ServerRole { none, dns, dhcp, dnsAndDhcp }

/// Resultado de una prueba de conectividad ("ping educativo").
enum PingResult { success, failure, pending }

/// Categoría de un problema detectado por el motor de diagnóstico.
enum IssueType {
  wrongIp,
  wrongMask,
  wrongGateway,
  disconnectedDevice,
  incompatibleSubnets,
  missingRoute,
  wrongDns,
  duplicateIp,
  disabledLink,
  isolatedDevice,
  incompleteConfiguration,
}

extension IssueTypeX on IssueType {
  String get label {
    switch (this) {
      case IssueType.wrongIp:
        return 'Dirección IP incorrecta';
      case IssueType.wrongMask:
        return 'Máscara incorrecta';
      case IssueType.wrongGateway:
        return 'Gateway incorrecto';
      case IssueType.disconnectedDevice:
        return 'Dispositivo desconectado';
      case IssueType.incompatibleSubnets:
        return 'Equipos en subredes incompatibles';
      case IssueType.missingRoute:
        return 'Ruta faltante';
      case IssueType.wrongDns:
        return 'DNS incorrecto';
      case IssueType.duplicateIp:
        return 'Dirección IP duplicada';
      case IssueType.disabledLink:
        return 'Conexión deshabilitada';
      case IssueType.isolatedDevice:
        return 'Dispositivo aislado';
      case IssueType.incompleteConfiguration:
        return 'Configuración incompleta';
    }
  }
}
