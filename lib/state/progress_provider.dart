import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progress_stats.dart';
import 'storage_provider.dart';

class ProgressNotifier extends StateNotifier<ProgressStats> {
  final Ref ref;
  ProgressNotifier(this.ref) : super(ref.read(storageServiceProvider).loadProgress());

  void _persist() => ref.read(storageServiceProvider).saveProgress(state);

  void registerNetworkConfigured() {
    state.networksConfigured++;
    state.bumpMastery('IPv4');
    state = ProgressStats.fromJson(state.toJson());
    _persist();
  }

  void registerPacketSimulated() {
    state.packetsSimulated++;
    state.bumpMastery('Switching', amount: 3);
    state.bumpMastery('Routing', amount: 3);
    state = ProgressStats.fromJson(state.toJson());
    _persist();
  }

  void registerProblemDiagnosed() {
    state.problemsDiagnosed++;
    state.bumpMastery('Diagnóstico', amount: 8);
    state = ProgressStats.fromJson(state.toJson());
    _persist();
  }

  void registerSubnettingExercise() {
    state.subnettingExercisesDone++;
    state.bumpMastery('Subnetting', amount: 10);
    state = ProgressStats.fromJson(state.toJson());
    _persist();
  }

  void registerServicePracticed(String area) {
    state.servicesConfigured++;
    state.bumpMastery(area, amount: 8);
    state = ProgressStats.fromJson(state.toJson());
    _persist();
  }

  void registerCaseCompleted() {
    state.casesCompleted++;
    state = ProgressStats.fromJson(state.toJson());
    _persist();
  }
}

final progressNotifierProvider =
    StateNotifierProvider<ProgressNotifier, ProgressStats>((ref) => ProgressNotifier(ref));
