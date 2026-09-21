import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../state/packet_journey_provider.dart';
import '../../state/workspace_provider.dart';
import '../widgets/workspace_canvas.dart';

/// Pantalla PACKET JOURNEY: el estudiante ve, salto a salto, cómo un
/// paquete recorre (o deja de recorrer) la topología real, con una
/// explicación breve en cada paso y controles de reproducción.
class PacketJourneyScreen extends ConsumerStatefulWidget {
  final String sourceDeviceId;
  final String destinationDeviceId;

  const PacketJourneyScreen({
    super.key,
    required this.sourceDeviceId,
    required this.destinationDeviceId,
  });

  @override
  ConsumerState<PacketJourneyScreen> createState() => _PacketJourneyScreenState();
}

class _PacketJourneyScreenState extends ConsumerState<PacketJourneyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scenario = ref.read(workspaceProvider);
      ref.read(packetJourneyProvider.notifier).runSimulation(
            scenario: scenario,
            sourceDeviceId: widget.sourceDeviceId,
            destinationDeviceId: widget.destinationDeviceId,
          );
    });
  }

  @override
  void dispose() {
    ref.read(packetJourneyProvider.notifier).reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scenario = ref.watch(workspaceProvider);
    final journey = ref.watch(packetJourneyProvider);
    final notifier = ref.read(packetJourneyProvider.notifier);

    if (!journey.hasResult) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final packet = journey.packet!;
    final visitedDeviceIds = packet.hops
        .take(journey.currentStep + 1)
        .map((h) => h.deviceId)
        .toSet();
    final currentHop = journey.currentHop;
    final isFailureNow = currentHop?.isFailure ?? false;

    // Construye el conjunto de enlaces recorridos hasta el paso actual
    // (para resaltarlos en amarillo señal sobre el canvas).
    final orderedVisited = packet.hops.take(journey.currentStep + 1).map((h) => h.deviceId).toList();
    final highlightedLinks = <String>{};
    for (var i = 0; i < orderedVisited.length - 1; i++) {
      if (orderedVisited[i] != orderedVisited[i + 1]) {
        highlightedLinks.add('${orderedVisited[i]}|${orderedVisited[i + 1]}');
      }
    }

    final markerDevice = currentHop != null ? scenario.deviceById(currentHop.deviceId) : null;
    final markerPosition = markerDevice?.position;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Packet Journey'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: WorkspaceCanvas(
              scenario: scenario,
              editable: false,
              highlightedDeviceIds: visitedDeviceIds,
              failureDeviceId: isFailureNow ? currentHop?.deviceId : null,
              highlightedLinkKeys: highlightedLinks,
              overlayMarker: markerDevice != null
                  ? Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isFailureNow ? NetVisionColors.dangerRed : NetVisionColors.signalYellow,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: (isFailureNow ? NetVisionColors.dangerRed : NetVisionColors.signalYellow)
                                .withValues(alpha: 0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    )
                  : null,
              overlayMarkerPosition: markerPosition != null
                  ? markerPosition + const Offset(kNodeSize / 2 + 12 - 11, kNodeSize / 2 - 11)
                  : null,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Paso ${journey.currentStep + 1} de ${packet.hops.length}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const Spacer(),
                      if (isFailureNow)
                        const Chip(
                          label: Text('¿Dónde se detuvo?'),
                          backgroundColor: Color(0x33E0533D),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        currentHop?.explanation ?? '',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  if (!packet.delivered && journey.isAtEnd)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: NetVisionColors.dangerRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Resumen: ${packet.summary}',
                          style: const TextStyle(color: NetVisionColors.dangerRed)),
                    ),
                  if (packet.delivered && journey.isAtEnd)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: NetVisionColors.successGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Resumen: ${packet.summary}',
                          style: const TextStyle(color: NetVisionColors.successGreen)),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        tooltip: 'Reiniciar',
                        icon: const Icon(Icons.restart_alt),
                        onPressed: notifier.restart,
                      ),
                      IconButton(
                        tooltip: 'Paso anterior',
                        icon: const Icon(Icons.skip_previous),
                        onPressed: journey.currentStep > 0 ? notifier.stepBackward : null,
                      ),
                      IconButton.filled(
                        tooltip: journey.isPlaying ? 'Pausar' : 'Reproducir',
                        icon: Icon(journey.isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: journey.isPlaying ? notifier.pause : notifier.play,
                      ),
                      IconButton(
                        tooltip: 'Siguiente paso',
                        icon: const Icon(Icons.skip_next),
                        onPressed: !journey.isAtEnd ? notifier.stepForward : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
