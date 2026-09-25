import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/case_completion_engine.dart';
import '../models/network_scenario.dart';
import 'case_progress_provider.dart';
import 'progress_provider.dart';

/// Evalúa si [scenario] (un caso profesional guiado) cumple realmente sus
/// condiciones de éxito y, si es así y no estaba ya registrado, marca el
/// caso como completado y actualiza el progreso global.
///
/// Se pensó para invocarse después de cualquier acción del estudiante que
/// pueda haber resuelto el caso (probar conectividad, solicitar DHCP,
/// resolver DNS, validar topología, generar el informe), de modo que el
/// progreso se detecte automáticamente en cuanto se cumplen los requisitos
/// reales del caso, sin depender de una única pantalla o botón. Nunca
/// registra el mismo caso dos veces.
///
/// Devuelve `true` si el caso se marcó como completado en esta llamada.
Future<bool> evaluateAndRegisterCaseCompletion(WidgetRef ref, NetworkScenario scenario) async {
  final caseNumber = scenario.caseNumber;
  if (!scenario.isBuiltInCase || caseNumber == null) return false;

  final alreadyCompleted = ref.read(caseProgressProvider).contains(caseNumber);
  if (alreadyCompleted) return false;

  final result = CaseCompletionEngine.evaluate(scenario);
  if (!result.success) return false;

  await ref.read(caseProgressProvider.notifier).markCompleted(caseNumber);
  ref.read(progressNotifierProvider.notifier).registerCaseCompleted();
  return true;
}
