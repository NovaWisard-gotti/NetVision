import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/simulation_engine.dart';
import '../models/network_scenario.dart';
import '../models/packet_hop.dart';
import 'progress_provider.dart';

/// Estado de la vista Packet Journey: el paquete simulado (si existe) y en
/// qué paso de la reproducción se encuentra el estudiante.
class PacketJourneyState {
  final SimulatedPacket? packet;
  final int currentStep; // índice del hop actualmente resaltado (-1 = nada)
  final bool isPlaying;

  const PacketJourneyState({
    this.packet,
    this.currentStep = -1,
    this.isPlaying = false,
  });

  bool get hasResult => packet != null;
  bool get isAtEnd => packet != null && currentStep >= packet!.hops.length - 1;
  PacketHop? get currentHop =>
      (packet != null && currentStep >= 0 && currentStep < packet!.hops.length)
          ? packet!.hops[currentStep]
          : null;

  PacketJourneyState copyWith({
    SimulatedPacket? packet,
    int? currentStep,
    bool? isPlaying,
  }) {
    return PacketJourneyState(
      packet: packet ?? this.packet,
      currentStep: currentStep ?? this.currentStep,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

class PacketJourneyNotifier extends StateNotifier<PacketJourneyState> {
  final Ref ref;
  Timer? _timer;

  PacketJourneyNotifier(this.ref) : super(const PacketJourneyState());

  void runSimulation({
    required NetworkScenario scenario,
    required String sourceDeviceId,
    required String destinationDeviceId,
  }) {
    _timer?.cancel();
    final result = SimulationEngine.simulate(
      scenario: scenario,
      sourceDeviceId: sourceDeviceId,
      destinationDeviceId: destinationDeviceId,
    );
    state = PacketJourneyState(packet: result, currentStep: 0, isPlaying: false);
    ref.read(progressNotifierProvider.notifier).registerPacketSimulated();
  }

  void reset() {
    _timer?.cancel();
    state = const PacketJourneyState();
  }

  void stepForward() {
    if (state.packet == null) return;
    if (state.currentStep < state.packet!.hops.length - 1) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    } else {
      pause();
    }
  }

  void stepBackward() {
    if (state.packet == null) return;
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void restart() {
    if (state.packet == null) return;
    _timer?.cancel();
    state = state.copyWith(currentStep: 0, isPlaying: false);
  }

  void play() {
    if (state.packet == null) return;
    _timer?.cancel();
    state = state.copyWith(isPlaying: true);
    _timer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (state.isAtEnd) {
        pause();
        return;
      }
      stepForward();
    });
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(isPlaying: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final packetJourneyProvider =
    StateNotifierProvider<PacketJourneyNotifier, PacketJourneyState>(
        (ref) => PacketJourneyNotifier(ref));
