import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:netvision/data/professional_cases.dart';
import 'package:netvision/persistence/local_storage_service.dart';
import 'package:netvision/state/case_completion_controller.dart';
import 'package:netvision/state/case_progress_provider.dart';
import 'package:netvision/state/progress_provider.dart';
import 'package:netvision/state/storage_provider.dart';

/// Monta un árbol mínimo con [ProviderScope] (apuntando al almacenamiento
/// indicado) y devuelve el [WidgetRef] capturado, listo para leer/llamar
/// providers exactamente como lo haría una pantalla real.
Future<WidgetRef> _pumpRef(WidgetTester tester, LocalStorageService storage) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          captured = ref;
          return const SizedBox.shrink();
        }),
      ),
    ),
  );
  return captured;
}

void main() {
  group('Persistencia del progreso de casos', () {
    testWidgets(
        'completar un caso se persiste, no se registra dos veces, y sigue completado tras "reabrir la app"',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final ref = await _pumpRef(tester, storage);

      // El Caso 1 ya es funcionalmente correcto por diseño (topología
      // provista sin fallas), así que la primera evaluación debería
      // completarlo de inmediato.
      final case1 = buildProfessionalCases().firstWhere((c) => c.caseNumber == 1);

      final firstAttempt = await evaluateAndRegisterCaseCompletion(ref, case1);
      expect(firstAttempt, true);
      expect(ref.read(caseProgressProvider), {1});
      expect(ref.read(progressNotifierProvider).casesCompleted, 1);

      // Volver a evaluar el mismo caso (ya resuelto) NO debe registrarlo de
      // nuevo ni volver a incrementar el contador de progreso.
      final secondAttempt = await evaluateAndRegisterCaseCompletion(ref, case1);
      expect(secondAttempt, false);
      expect(ref.read(caseProgressProvider), {1});
      expect(ref.read(progressNotifierProvider).casesCompleted, 1);

      // ProgressNotifier persiste el contador de forma "fire-and-forget"
      // (no espera su propio Future de guardado), así que se deja que la
      // cola de microtareas drene antes de simular el cierre de la app;
      // de lo contrario esta prueba sería intermitente por una carrera de
      // temporización propia del test, no un bug de la app.
      await tester.pump(const Duration(milliseconds: 50));

      // Simula cerrar y volver a abrir NetVision: primero se desmonta por
      // completo el árbol actual (lo que destruye el ProviderContainer y
      // todo su estado en memoria, igual que cerrar la app), y luego se
      // monta uno nuevo que solo puede reconstruir su estado leyendo lo que
      // haya quedado realmente persistido en el almacenamiento.
      await tester.pumpWidget(const SizedBox.shrink());
      final reloadedStorage = await LocalStorageService.create();
      final reloadedRef = await _pumpRef(tester, reloadedStorage);

      expect(reloadedRef.read(caseProgressProvider), {1},
          reason: 'El caso debe seguir marcado como completado tras recargar.');
      expect(reloadedRef.read(progressNotifierProvider).casesCompleted, 1,
          reason: 'El contador de progreso no debe haberse duplicado.');

      // Y evaluarlo una vez más después de "reabrir" tampoco debe duplicar
      // el registro.
      final thirdAttempt = await evaluateAndRegisterCaseCompletion(reloadedRef, case1);
      expect(thirdAttempt, false);
      expect(reloadedRef.read(caseProgressProvider), {1});
      expect(reloadedRef.read(progressNotifierProvider).casesCompleted, 1);
    });

    testWidgets('completar dos casos distintos suma correctamente el progreso (2/5, no 1/5 ni 3/5)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.create();
      final ref = await _pumpRef(tester, storage);

      final case1 = buildProfessionalCases().firstWhere((c) => c.caseNumber == 1);
      final case2 = buildProfessionalCases().firstWhere((c) => c.caseNumber == 2);

      await evaluateAndRegisterCaseCompletion(ref, case1);
      await evaluateAndRegisterCaseCompletion(ref, case2);
      // Reintentar ambos no debe alterar el conteo.
      await evaluateAndRegisterCaseCompletion(ref, case1);
      await evaluateAndRegisterCaseCompletion(ref, case2);

      expect(ref.read(caseProgressProvider), {1, 2});
      expect(ref.read(progressNotifierProvider).casesCompleted, 2);
    });
  });
}
