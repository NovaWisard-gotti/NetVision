import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../engine/addressing_engine.dart';

/// Representación visual de un bloque IPv4: qué parte corresponde a la red,
/// a los hosts utilizables y al broadcast. No representa los 32 bits
/// constantemente; solo se usa cuando aporta valor educativo (Taller de
/// subnetting y Visualizador de direcciones).
class AddressVisualizer extends StatelessWidget {
  final String networkAddress;
  final int prefixLength;

  const AddressVisualizer({
    super.key,
    required this.networkAddress,
    required this.prefixLength,
  });

  @override
  Widget build(BuildContext context) {
    final broadcast = AddressingEngine.broadcastAddress(networkAddress, prefixLength);
    final hostRange = AddressingEngine.usableHostRange(networkAddress, prefixLength);
    final totalHosts = AddressingEngine.totalHosts(prefixLength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    color: NetVisionColors.cobalt,
                    alignment: Alignment.center,
                    child: const Text('RED', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Container(
                    color: NetVisionColors.aqua,
                    alignment: Alignment.center,
                    child: Text('HOSTS ($totalHosts)',
                        style: const TextStyle(color: Color(0xFF00332C), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    color: NetVisionColors.signalYellow,
                    alignment: Alignment.center,
                    child: const Text('BCAST', style: TextStyle(color: Color(0xFF3A2900), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _line('Dirección de red', networkAddress),
        if (hostRange != null) _line('Primer host utilizable', hostRange.$1),
        if (hostRange != null) _line('Último host utilizable', hostRange.$2),
        _line('Broadcast', broadcast),
      ],
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
