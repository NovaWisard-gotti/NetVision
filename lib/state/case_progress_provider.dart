import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_provider.dart';

class CaseProgressNotifier extends StateNotifier<Set<int>> {
  final Ref ref;
  CaseProgressNotifier(this.ref)
      : super(ref.read(storageServiceProvider).loadCompletedCaseNumbers());

  Future<void> markCompleted(int caseNumber) async {
    await ref.read(storageServiceProvider).markCaseCompleted(caseNumber);
    state = ref.read(storageServiceProvider).loadCompletedCaseNumbers();
  }
}

final caseProgressProvider =
    StateNotifierProvider<CaseProgressNotifier, Set<int>>((ref) => CaseProgressNotifier(ref));
