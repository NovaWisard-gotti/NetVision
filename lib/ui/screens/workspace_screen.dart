import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../engine/case_completion_engine.dart';
import '../../engine/diagnostics_engine.dart';
import '../../engine/simulation_engine.dart';
import '../../models/network_scenario.dart';
import '../../state/case_completion_controller.dart';
import '../../state/history_provider.dart';
import '../../state/progress_provider.dart';
import '../../state/storage_provider.dart';
import '../../state/workspace_provider.dart';
import '../../models/history_entry.dart';
import '../widgets/device_config_sheet.dart';
import '../widgets/device_picker_dialog.dart';
import '../widgets/device_palette.dart';
import '../widgets/ping_result_dialog.dart';
import '../widgets/workspace_canvas.dart';
import 'packet_journey_screen.dart';
import 'report_screen.dart';
import 'topology_validation_sheet.dart';

/// El NetVision Workspace: el lienzo principal donde el estudiante
/// construye, conecta, configura y prueba topologías. Sirve tanto para el
/// sandbox libre (Modo Diseño) como para los casos profesionales guiados.
///
/// Si [caseScenario] no es null, el Workspace carga ese caso (retomando una
/// práctica guardada si existe) en lugar del sandbox libre. Si además el
/// caso trae [NetworkScenario.hiddenFaultDescription], se activan las
/// herramientas de Network Doctor (pista + verificar solución).
class WorkspaceScreen extends ConsumerStatefulWidget {
  final NetworkScenario? caseScenario;

  const WorkspaceScreen({super.key, this.caseScenario});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  bool _connectMode = false;
  int _hintLevel = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = ref.read(storageServiceProvider);
      final caseScenario = widget.caseScenario;
      if (caseScenario != null) {
        final saved = storage.findSavedScenario(caseScenario.id);
        ref.read(workspaceProvider.notifier).loadScenario(
              saved ?? caseScenario,
              sandbox: false,
            );
      } else {
        // Se entra al sandbox libre: si el Workspace compartido tenía
        // cargado un caso de una navegación anterior, se recupera el
        // sandbox persistido (o uno vacío si es la primera vez).
        final wasSandbox = ref.read(workspaceProvider.notifier).isSandbox;
        if (!wasSandbox) {
          final sandbox = storage.loadSandbox() ?? emptyScenario();
          ref.read(workspaceProvider.notifier).loadScenario(sandbox, sandbox: true);
        }
      }
    });
  }

  bool get _isDoctorCase => widget.caseScenario?.hiddenFaultDescription != null;

  void _openDeviceSheet(String deviceId) {
    if (_connectMode) {
      final pending = ref.read(pendingConnectionSourceProvider);
      if (pending == null) {
        ref.read(pendingConnectionSourceProvider.notifier).state = deviceId;
      } else if (pending == deviceId) {
        ref.read(pendingConnectionSourceProvider.notifier).state = null;
      } else {
        final error = ref.read(workspaceProvider.notifier).connectDevices(pending, deviceId);
        ref.read(pendingConnectionSourceProvider.notifier).state = null;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
      }
      return;
    }
    ref.read(selectedDeviceIdProvider.notifier).state = deviceId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeviceConfigSheet(deviceId: deviceId),
    ).whenComplete(() {
      ref.read(selectedDeviceIdProvider.notifier).state = null;
    });
  }

  Future<void> _testConnectivity() async {
    final scenario = ref.read(workspaceProvider);
    final sourceId = await showDevicePickerDialog(context, scenario: scenario, title: 'Elige el origen');
    if (sourceId == null || !mounted) return;
    final destId = await showDevicePickerDialog(
      context,
      scenario: scenario,
      title: 'Elige el destino',
      excludeDeviceId: sourceId,
    );
    if (destId == null || !mounted) return;
    final result = SimulationEngine.simulate(
      scenario: scenario,
      sourceDeviceId: sourceId,
      destinationDeviceId: destId,
    );
    ref.read(progressNotifierProvider.notifier).registerPacketSimulated();
    final justCompleted = await evaluateAndRegisterCaseCompletion(ref, ref.read(workspaceProvider));
    if (!mounted) return;
    showDialog(context: context, builder: (_) => PingResultDialog(packet: result));
    if (justCompleted) _showCaseCompletedSnackBar();
  }

  void _showCaseCompletedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('¡Caso completado! Se actualizó tu progreso.'),
    ));
  }

  Future<void> _openPacketJourney() async {
    final scenario = ref.read(workspaceProvider);
    final sourceId = await showDevicePickerDialog(context, scenario: scenario, title: 'Origen del paquete');
    if (sourceId == null || !mounted) return;
    final destId = await showDevicePickerDialog(
      context,
      scenario: scenario,
      title: 'Destino del paquete',
      excludeDeviceId: sourceId,
    );
    if (destId == null || !mounted) return;
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PacketJourneyScreen(sourceDeviceId: sourceId, destinationDeviceId: destId),
    ));
  }

  void _showHint() {
    final scenario = ref.read(workspaceProvider);
    setState(() => _hintLevel = (_hintLevel + 1).clamp(0, 2));
    String message;
    switch (_hintLevel) {
      case 1:
        message =
            'Pista 1: usa "Probar conectividad" entre distintos pares de dispositivos para '
            'localizar exactamente dónde deja de funcionar la comunicación.';
        break;
      default:
        message = 'Pista 2: revisa cuidadosamente la configuración IPv4 (dirección, máscara, '
            'gateway) de cada equipo involucrado en la falla. Compárala con la de sus compañeros.';
    }
    if (_hintLevel >= 2 && scenario.hiddenFaultDescription != null) {
      message += '\n\nSi ya lo intentaste y sigues sin encontrarla, aquí está el diagnóstico '
          'completo:\n${scenario.hiddenFaultDescription}';
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pista de Network Doctor'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido')),
        ],
      ),
    );
  }

  Future<void> _verifyDoctorSolution() async {
    final scenario = ref.read(workspaceProvider);
    final sourceId = scenario.testSourceDeviceId;
    final destId = scenario.testDestinationDeviceId;
    if (sourceId == null || destId == null) return;
    final result = SimulationEngine.simulate(
      scenario: scenario,
      sourceDeviceId: sourceId,
      destinationDeviceId: destId,
    );
    if (result.delivered) {
      await evaluateAndRegisterCaseCompletion(ref, scenario);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.celebration, color: NetVisionColors.successGreen),
            SizedBox(width: 8),
            Text('¡Problema resuelto!'),
          ]),
          content: const Text(
              'La comunicación entre los equipos afectados ahora funciona correctamente. '
              'Puedes generar el informe del caso desde el ícono superior.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Continuar')),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => PingResultDialog(packet: result),
      );
    }
  }

  Future<void> _validateTopology() async {
    final scenario = ref.read(workspaceProvider);
    final issues = DiagnosticsEngine.analyze(scenario);
    if (issues.isNotEmpty) {
      ref.read(progressNotifierProvider.notifier).registerProblemDiagnosed();
    }
    final justCompleted = await evaluateAndRegisterCaseCompletion(ref, scenario);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TopologyValidationSheet(issues: issues),
    );
    if (justCompleted) _showCaseCompletedSnackBar();
  }

  Future<void> _finishAndReport() async {
    final scenario = ref.read(workspaceProvider);
    final completion = CaseCompletionEngine.evaluate(scenario);
    await evaluateAndRegisterCaseCompletion(ref, scenario);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportScreen(scenario: scenario, completion: completion),
    ));
    if (!mounted) return;
    await ref.read(historyProvider.notifier).addEntry(HistoryEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          caseTitle: scenario.title,
          date: DateTime.now(),
          scenarioSnapshotJson: '',
          completed: completion.success,
          problemsFound: completion.issues.map((i) => i.description).toList(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final scenario = ref.watch(workspaceProvider);
    final selectedId = ref.watch(selectedDeviceIdProvider);
    final pendingSource = ref.watch(pendingConnectionSourceProvider);
    final atLimit = scenario.devices.length >= ref.read(workspaceProvider.notifier).deviceLimit;

    return Scaffold(
      appBar: AppBar(
        title: Text(scenario.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_isDoctorCase) ...[
            IconButton(
              tooltip: 'Pista',
              icon: const Icon(Icons.lightbulb_outline),
              onPressed: _showHint,
            ),
            IconButton(
              tooltip: 'Verificar solución',
              icon: const Icon(Icons.health_and_safety_outlined),
              onPressed: _verifyDoctorSolution,
            ),
          ],
          IconButton(
            tooltip: 'Validar topología',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: _validateTopology,
          ),
          IconButton(
            tooltip: 'Probar conectividad',
            icon: const Icon(Icons.wifi_tethering),
            onPressed: _testConnectivity,
          ),
          IconButton(
            tooltip: 'Packet Journey',
            icon: const Icon(Icons.route_outlined),
            onPressed: _openPacketJourney,
          ),
          IconButton(
            tooltip: 'Generar informe',
            icon: const Icon(Icons.summarize_outlined),
            onPressed: _finishAndReport,
          ),
        ],
      ),
      body: Column(
        children: [
          if (scenario.objective.isNotEmpty)
            Container(
              width: double.infinity,
              color: NetVisionColors.cobalt.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                scenario.objective,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (_connectMode)
            Container(
              width: double.infinity,
              color: NetVisionColors.signalYellow.withValues(alpha: 0.18),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                pendingSource == null
                    ? 'Modo conectar: toca el primer dispositivo.'
                    : 'Ahora toca el dispositivo con el que quieres conectarlo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: WorkspaceCanvas(
              scenario: scenario,
              editable: true,
              selectedDeviceId: selectedId,
              pendingConnectionSourceId: pendingSource,
              onDeviceTap: _openDeviceSheet,
              onDeviceMoved: (id, pos) =>
                  ref.read(workspaceProvider.notifier).moveDevice(id, pos),
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DevicePalette(
                        enabled: !atLimit,
                        onDeviceSelected: (type) {
                          final error = ref.read(workspaceProvider.notifier).addDevice(
                                type,
                                const Offset(140, 140),
                              );
                          if (error != null) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(error)));
                          } else {
                            ref.read(progressNotifierProvider.notifier).registerNetworkConfigured();
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: FilterChip(
                        label: const Text('Conectar'),
                        avatar: const Icon(Icons.cable, size: 18),
                        selected: _connectMode,
                        onSelected: (v) {
                          setState(() => _connectMode = v);
                          ref.read(pendingConnectionSourceProvider.notifier).state = null;
                        },
                      ),
                    ),
                  ],
                ),
                if (atLimit)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Límite de dispositivos alcanzado para mantener estabilidad.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
