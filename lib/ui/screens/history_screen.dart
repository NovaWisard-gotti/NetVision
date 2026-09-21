import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../state/history_provider.dart';

/// Historial local de prácticas: caso, fecha, resultado y problemas
/// encontrados. Permite ver qué se practicó, aunque el reabrir para seguir
/// editando se hace desde la lista de Casos (que ya recuerda el progreso).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: history.isEmpty
          ? const Center(child: Text('Todavía no has completado ninguna práctica.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final entry = history[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(
                      entry.completed ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: entry.completed ? NetVisionColors.successGreen : NetVisionColors.signalYellow,
                    ),
                    title: Text(entry.caseTitle),
                    subtitle: Text(
                      '${_formatDate(entry.date)}'
                      '${entry.problemsFound.isNotEmpty ? "\n${entry.problemsFound.length} problema(s) registrado(s)" : ""}',
                    ),
                    isThreeLine: entry.problemsFound.isNotEmpty,
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
