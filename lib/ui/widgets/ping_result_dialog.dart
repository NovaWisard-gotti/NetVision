import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/packet_hop.dart';

/// Resultado del "Ping educativo" (Probar conectividad): una versión
/// resumida del Packet Journey pensada para una verificación rápida sin
/// entrar al modo de reproducción paso a paso.
class PingResultDialog extends StatelessWidget {
  final SimulatedPacket packet;

  const PingResultDialog({super.key, required this.packet});

  @override
  Widget build(BuildContext context) {
    final lastHop = packet.hops.isNotEmpty ? packet.hops.last : null;
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            packet.delivered ? Icons.check_circle : Icons.error_outline,
            color: packet.delivered ? NetVisionColors.successGreen : NetVisionColors.dangerRed,
          ),
          const SizedBox(width: 8),
          Text(packet.delivered ? 'Conectividad exitosa' : 'Sin conectividad'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('Origen', packet.sourceIp.isEmpty ? '—' : packet.sourceIp),
              _row('Destino', packet.destinationIp.isEmpty ? '—' : packet.destinationIp),
              _row('Resultado', packet.delivered ? 'Éxito' : 'Fallo'),
              const SizedBox(height: 12),
              Text('Recorrido:', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              ...packet.hops.map((h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          h.isFailure ? Icons.close : Icons.arrow_downward,
                          size: 16,
                          color: h.isFailure ? NetVisionColors.dangerRed : NetVisionColors.titaniumDark,
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(h.deviceName, style: const TextStyle(fontWeight: FontWeight.w600))),
                      ],
                    ),
                  )),
              if (!packet.delivered && lastHop != null) ...[
                const SizedBox(height: 12),
                Text('Posible causa del fallo:', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(lastHop.explanation),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
