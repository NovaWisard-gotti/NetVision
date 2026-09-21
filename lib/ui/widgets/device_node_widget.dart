import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/enums.dart';
import '../../models/network_device.dart';
import 'device_visuals_helper.dart';

/// Tamaño táctil del nodo (suficientemente grande para dedos, según regla
/// de diseño para pantallas táctiles).
const double kNodeSize = 84;

class DeviceNodeWidget extends StatelessWidget {
  final NetworkDevice device;
  final bool isSelected;
  final bool isPendingConnectionSource;
  final bool isHighlighted; // usado por Packet Journey / Network Doctor
  final bool isFailureHighlight;
  final VoidCallback? onTap;

  const DeviceNodeWidget({
    super.key,
    required this.device,
    this.isSelected = false,
    this.isPendingConnectionSource = false,
    this.isHighlighted = false,
    this.isFailureHighlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = DeviceVisualsHelper.colorFor(device.type);
    final icon = DeviceVisualsHelper.iconFor(device.type);
    final scheme = Theme.of(context).colorScheme;

    Color borderColor = scheme.outline.withValues(alpha: 0.4);
    double borderWidth = 1.5;
    if (isPendingConnectionSource) {
      borderColor = NetVisionColors.signalYellow;
      borderWidth = 3;
    } else if (isFailureHighlight) {
      borderColor = NetVisionColors.dangerRed;
      borderWidth = 3;
    } else if (isHighlighted) {
      borderColor = NetVisionColors.signalYellow;
      borderWidth = 3;
    } else if (isSelected) {
      borderColor = scheme.primary;
      borderWidth = 3;
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: kNodeSize + 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: kNodeSize,
              height: kNodeSize,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: color, size: 36),
                  if (device.manuallyDisconnected)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: NetVisionColors.dangerRed,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                device.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (device.type.supportsIpv4Configuration &&
                device.primaryInterface?.ipv4?.address.isNotEmpty == true)
              Text(
                device.primaryInterface!.ipv4!.address,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
