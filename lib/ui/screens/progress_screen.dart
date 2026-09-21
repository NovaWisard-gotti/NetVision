import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../state/case_progress_provider.dart';
import '../../state/progress_provider.dart';

/// Pantalla de progreso: casos completados, redes configuradas, paquetes
/// simulados, problemas diagnosticados, ejercicios de subnetting, servicios
/// practicados y dominio por área. Sin monedas, XP, vidas ni rankings.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(progressNotifierProvider);
    final completedCases = ref.watch(caseProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progreso')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _StatTile(label: 'Casos completados', value: '${completedCases.length}/5')),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(label: 'Redes configuradas', value: '${stats.networksConfigured}')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _StatTile(label: 'Paquetes simulados', value: '${stats.packetsSimulated}')),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(label: 'Problemas diagnosticados', value: '${stats.problemsDiagnosed}')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _StatTile(label: 'Ejercicios de subnetting', value: '${stats.subnettingExercisesDone}')),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(label: 'Servicios practicados', value: '${stats.servicesConfigured}')),
            ],
          ),
          const SizedBox(height: 24),
          Text('Dominio por área', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (final entry in stats.masteryByArea.entries) _MasteryBar(area: entry.key, value: entry.value),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MasteryBar extends StatelessWidget {
  final String area;
  final int value;
  const _MasteryBar({required this.area, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(area, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('$value%'),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 8,
              backgroundColor: NetVisionColors.titanium.withValues(alpha: 0.35),
              valueColor: const AlwaysStoppedAnimation(NetVisionColors.aqua),
            ),
          ),
        ],
      ),
    );
  }
}
