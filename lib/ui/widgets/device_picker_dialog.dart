import 'package:flutter/material.dart';
import '../../models/enums.dart';
import '../../models/network_device.dart';
import '../../models/network_scenario.dart';
import 'device_visuals_helper.dart';

/// Diálogo simple para elegir un dispositivo de la topología actual (usado
/// por Probar conectividad y Packet Journey para elegir origen/destino).
Future<String?> showDevicePickerDialog(
  BuildContext context, {
  required NetworkScenario scenario,
  required String title,
  String? excludeDeviceId,
}) {
  final candidates = scenario.devices
      .where((d) => d.type.supportsIpv4Configuration)
      .where((d) => d.id != excludeDeviceId)
      .toList();

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: candidates.isEmpty
            ? const Text('No hay dispositivos con IPv4 disponibles en esta topología.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  final NetworkDevice d = candidates[index];
                  return ListTile(
                    leading: Icon(DeviceVisualsHelper.iconFor(d.type),
                        color: DeviceVisualsHelper.colorFor(d.type)),
                    title: Text(d.name),
                    subtitle: Text(d.primaryInterface?.ipv4?.address.isNotEmpty == true
                        ? d.primaryInterface!.ipv4!.address
                        : 'Sin IP configurada'),
                    onTap: () => Navigator.of(context).pop(d.id),
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      ],
    ),
  );
}
