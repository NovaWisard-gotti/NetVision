import 'package:flutter/material.dart';
import '../../models/enums.dart';
import 'device_visuals_helper.dart';

/// Barra horizontal para añadir dispositivos al Workspace.
class DevicePalette extends StatelessWidget {
  final void Function(DeviceType type) onDeviceSelected;
  final bool enabled;

  const DevicePalette({super.key, required this.onDeviceSelected, this.enabled = true});

  static const _types = [
    DeviceType.pc,
    DeviceType.laptop,
    DeviceType.server,
    DeviceType.switchDevice,
    DeviceType.router,
    DeviceType.accessPoint,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = _types[index];
          final color = DeviceVisualsHelper.colorFor(type);
          return Opacity(
            opacity: enabled ? 1 : 0.4,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: enabled ? () => onDeviceSelected(type) : null,
              child: Container(
                width: 76,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(DeviceVisualsHelper.iconFor(type), color: color),
                    const SizedBox(height: 4),
                    Text(
                      type.label,
                      style: Theme.of(context).textTheme.labelSmall,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
