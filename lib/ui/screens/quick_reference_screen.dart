import 'package:flutter/material.dart';
import '../../data/quick_reference_content.dart';

/// Referencia breve de conceptos de redes. Explicaciones cortas: NetVision
/// no pretende ser un libro digital.
class QuickReferenceScreen extends StatelessWidget {
  const QuickReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consulta rápida')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: quickReferenceEntries.length,
        itemBuilder: (context, index) {
          final entry = quickReferenceEntries[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.term, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(entry.explanation),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
