import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../engine/addressing_engine.dart';
import '../../state/progress_provider.dart';
import '../widgets/address_visualizer.dart';

/// TALLER DE SUBNETTING: el estudiante recibe una red base y una cantidad
/// de subredes deseadas, y la aplicación calcula progresivamente:
/// RED ORIGINAL -> PREFIJO -> SUBREDES -> RANGO DE HOSTS -> BROADCAST.
class SubnettingWorkshopScreen extends ConsumerStatefulWidget {
  const SubnettingWorkshopScreen({super.key});

  @override
  ConsumerState<SubnettingWorkshopScreen> createState() => _SubnettingWorkshopScreenState();
}

class _SubnettingWorkshopScreenState extends ConsumerState<SubnettingWorkshopScreen> {
  final _networkCtrl = TextEditingController(text: '192.168.0.0');
  final _prefixCtrl = TextEditingController(text: '24');
  final _countCtrl = TextEditingController(text: '4');

  List<(String network, int prefix)>? _result;
  String? _explanation;
  String? _error;

  @override
  void dispose() {
    _networkCtrl.dispose();
    _prefixCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final network = _networkCtrl.text.trim();
    final prefix = int.tryParse(_prefixCtrl.text.trim());
    final count = int.tryParse(_countCtrl.text.trim());

    if (!AddressingEngine.isValidIpv4(network)) {
      setState(() {
        _error = 'La red base no es una dirección IPv4 válida.';
        _result = null;
      });
      return;
    }
    if (prefix == null || !AddressingEngine.isValidPrefix(prefix)) {
      setState(() {
        _error = 'El prefijo original debe estar entre 0 y 32.';
        _result = null;
      });
      return;
    }
    if (count == null || count < 1) {
      setState(() {
        _error = 'Indica al menos 1 subred.';
        _result = null;
      });
      return;
    }

    try {
      final divided = AddressingEngine.divideIntoSubnets(network, prefix, count);
      final bitsNeeded = AddressingEngine.bitsNeededForSubnetCount(count);
      final totalPossible = 1 << bitsNeeded;
      final leftover = totalPossible - count;
      final newPrefix = divided.first.$2;
      setState(() {
        _result = divided;
        _explanation = leftover > 0
            ? 'Para obtener al menos $count subred(es) se necesitan $bitsNeeded bit(s) adicionales. '
                'Esto genera $totalPossible subredes /$newPrefix. Se muestran las primeras $count '
                'solicitadas y quedan $leftover subred(es) disponible(s) para uso futuro.'
            : 'Para obtener exactamente $count subred(es) se necesitan $bitsNeeded bit(s) adicionales, '
                'lo que genera exactamente $totalPossible subredes /$newPrefix.';
        _error = null;
      });
      ref.read(progressNotifierProvider.notifier).registerSubnettingExercise();
    } catch (e) {
      setState(() {
        _error = e is ArgumentError ? e.message.toString() : 'No fue posible calcular las subredes.';
        _result = null;
        _explanation = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Taller de subnetting')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ejemplo: "Una red necesita dividirse en cuatro subredes." '
            'Ingresa la red original, su prefijo y la cantidad de subredes requeridas.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _networkCtrl,
                  decoration: const InputDecoration(labelText: 'Red original (ej. 192.168.0.0)'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _prefixCtrl,
                  decoration: const InputDecoration(labelText: 'Prefijo'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _countCtrl,
            decoration: const InputDecoration(labelText: 'Número de subredes necesarias'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Calcular subredes'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: NetVisionColors.dangerRed)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            Text(
              'Nuevo prefijo: /${_result!.first.$2}  ·  ${_result!.length} subred(es) generadas',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_explanation != null) ...[
              const SizedBox(height: 8),
              Text(_explanation!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            for (var i = 0; i < _result!.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subred ${i + 1}: ${_result![i].$1}/${_result![i].$2}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      AddressVisualizer(networkAddress: _result![i].$1, prefixLength: _result![i].$2),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
