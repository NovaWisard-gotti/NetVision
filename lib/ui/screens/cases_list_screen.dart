import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../state/case_progress_provider.dart';
import '../../state/cases_provider.dart';
import '../../state/storage_provider.dart';
import 'workspace_screen.dart';

/// Lista de los cinco casos profesionales. Permite abrir un caso desde
/// cero o continuar una práctica guardada.
class CasesListScreen extends ConsumerWidget {
  const CasesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(professionalCasesProvider);
    final completed = ref.watch(caseProgressProvider);
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Casos profesionales')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: cases.length,
        itemBuilder: (context, index) {
          final c = cases[index];
          final isCompleted = completed.contains(c.caseNumber);
          final hasSavedProgress = storage.findSavedScenario(c.id) != null;
          final isDoctor = c.hiddenFaultDescription != null;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: CircleAvatar(
                backgroundColor: isCompleted
                    ? NetVisionColors.successGreen.withValues(alpha: 0.15)
                    : NetVisionColors.cobalt.withValues(alpha: 0.1),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle
                      : (isDoctor ? Icons.health_and_safety_outlined : Icons.route_outlined),
                  color: isCompleted ? NetVisionColors.successGreen : NetVisionColors.cobalt,
                ),
              ),
              title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(c.objective, maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
              isThreeLine: true,
              trailing: hasSavedProgress && !isCompleted
                  ? const Icon(Icons.play_circle_outline)
                  : const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => WorkspaceScreen(caseScenario: c),
                ));
              },
            ),
          );
        },
      ),
    );
  }
}
