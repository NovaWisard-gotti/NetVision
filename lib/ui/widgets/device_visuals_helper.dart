import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/enums.dart';

/// Ayudas visuales compartidas para representar dispositivos de forma
/// consistente en todo NetVision (Workspace, Packet Journey, Network
/// Doctor, informes).
class DeviceVisualsHelper {
  const DeviceVisualsHelper._();

  static IconData iconFor(DeviceType type) {
    switch (type) {
      case DeviceType.pc:
        return Icons.desktop_windows_rounded;
      case DeviceType.laptop:
        return Icons.laptop_mac_rounded;
      case DeviceType.server:
        return Icons.dns_rounded;
      case DeviceType.switchDevice:
        return Icons.lan_rounded;
      case DeviceType.router:
        return Icons.router_rounded;
      case DeviceType.accessPoint:
        return Icons.wifi_tethering_rounded;
    }
  }

  static Color colorFor(DeviceType type) {
    switch (type) {
      case DeviceType.pc:
        return DeviceVisuals.pcColor;
      case DeviceType.laptop:
        return DeviceVisuals.laptopColor;
      case DeviceType.server:
        return DeviceVisuals.serverColor;
      case DeviceType.switchDevice:
        return DeviceVisuals.switchColor;
      case DeviceType.router:
        return DeviceVisuals.routerColor;
      case DeviceType.accessPoint:
        return DeviceVisuals.apColor;
    }
  }
}
