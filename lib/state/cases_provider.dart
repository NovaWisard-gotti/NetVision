import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/professional_cases.dart';
import '../models/network_scenario.dart';

final professionalCasesProvider = Provider<List<NetworkScenario>>((ref) {
  return buildProfessionalCases();
});
