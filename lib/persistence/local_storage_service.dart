import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_entry.dart';
import '../models/network_scenario.dart';
import '../models/progress_stats.dart';

/// Servicio de persistencia local para NetVision.
///
/// Toda la aplicación funciona offline: se usa `shared_preferences` como
/// almacenamiento simple de documentos JSON. Las topologías NUNCA se
/// guardan como imágenes; se serializan completas (dispositivos, interfaces,
/// configuración y conexiones) para poder reabrirse y editarse.
class LocalStorageService {
  static const _kSandbox = 'netvision_sandbox_v1';
  static const _kSavedScenarios = 'netvision_saved_scenarios_v1';
  static const _kHistory = 'netvision_history_v1';
  static const _kProgress = 'netvision_progress_v1';
  static const _kThemeMode = 'netvision_theme_mode_v1';
  static const _kCaseProgress = 'netvision_case_progress_v1';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  // ---------------------------------------------------------------------
  // Sandbox (Modo Diseño)
  // ---------------------------------------------------------------------

  Future<void> saveSandbox(NetworkScenario scenario) async {
    await _prefs.setString(_kSandbox, jsonEncode(scenario.toJson()));
  }

  NetworkScenario? loadSandbox() {
    final raw = _prefs.getString(_kSandbox);
    if (raw == null) return null;
    try {
      return NetworkScenario.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // Escenarios guardados por el estudiante
  // ---------------------------------------------------------------------

  List<NetworkScenario> loadSavedScenarios() {
    final raw = _prefs.getStringList(_kSavedScenarios) ?? [];
    return raw
        .map((s) {
          try {
            return NetworkScenario.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<NetworkScenario>()
        .toList();
  }

  Future<void> saveScenarioList(List<NetworkScenario> scenarios) async {
    final raw = scenarios.map((s) => jsonEncode(s.toJson())).toList();
    await _prefs.setStringList(_kSavedScenarios, raw);
  }

  /// Guarda o reemplaza (por id) un escenario dentro de la lista de
  /// escenarios guardados. Se usa para permitir continuar prácticas de
  /// casos profesionales incompletas.
  Future<void> upsertScenario(NetworkScenario scenario) async {
    final current = loadSavedScenarios();
    final index = current.indexWhere((s) => s.id == scenario.id);
    if (index >= 0) {
      current[index] = scenario;
    } else {
      current.add(scenario);
    }
    await saveScenarioList(current);
  }

  NetworkScenario? findSavedScenario(String id) {
    for (final s in loadSavedScenarios()) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Historial
  // ---------------------------------------------------------------------

  List<HistoryEntry> loadHistory() {
    final raw = _prefs.getStringList(_kHistory) ?? [];
    return raw
        .map((s) {
          try {
            return HistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<HistoryEntry>()
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> addHistoryEntry(HistoryEntry entry) async {
    final current = _prefs.getStringList(_kHistory) ?? [];
    current.add(jsonEncode(entry.toJson()));
    await _prefs.setStringList(_kHistory, current);
  }

  // ---------------------------------------------------------------------
  // Progreso
  // ---------------------------------------------------------------------

  ProgressStats loadProgress() {
    final raw = _prefs.getString(_kProgress);
    if (raw == null) return ProgressStats();
    try {
      return ProgressStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ProgressStats();
    }
  }

  Future<void> saveProgress(ProgressStats stats) async {
    await _prefs.setString(_kProgress, jsonEncode(stats.toJson()));
  }

  // ---------------------------------------------------------------------
  // Progreso de casos guiados (qué casos ya se completaron al menos una vez)
  // ---------------------------------------------------------------------

  Set<int> loadCompletedCaseNumbers() {
    final raw = _prefs.getStringList(_kCaseProgress) ?? [];
    return raw.map(int.parse).toSet();
  }

  Future<void> markCaseCompleted(int caseNumber) async {
    final completed = loadCompletedCaseNumbers();
    completed.add(caseNumber);
    await _prefs.setStringList(
        _kCaseProgress, completed.map((e) => e.toString()).toList());
  }

  // ---------------------------------------------------------------------
  // Preferencia de tema
  // ---------------------------------------------------------------------

  String? loadThemeMode() => _prefs.getString(_kThemeMode);

  Future<void> saveThemeMode(String mode) async {
    await _prefs.setString(_kThemeMode, mode);
  }
}
