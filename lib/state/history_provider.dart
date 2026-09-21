import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/history_entry.dart';
import 'storage_provider.dart';

class HistoryNotifier extends StateNotifier<List<HistoryEntry>> {
  final Ref ref;
  HistoryNotifier(this.ref) : super(ref.read(storageServiceProvider).loadHistory());

  Future<void> addEntry(HistoryEntry entry) async {
    await ref.read(storageServiceProvider).addHistoryEntry(entry);
    state = ref.read(storageServiceProvider).loadHistory();
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<HistoryEntry>>((ref) => HistoryNotifier(ref));
