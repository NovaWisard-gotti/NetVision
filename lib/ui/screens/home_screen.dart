import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../state/theme_provider.dart';
import 'cases_list_screen.dart';
import 'history_screen.dart';
import 'progress_screen.dart';
import 'quick_reference_screen.dart';
import 'subnetting_workshop_screen.dart';
import 'workspace_screen.dart';

/// Pantalla inicial de NetVision: acceso al Workspace (sandbox), a los
/// casos profesionales, al taller de subnetting, al progreso, al
/// historial y a la consulta rápida.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NetVision'),
        actions: [
          PopupMenuButton<ThemeMode>(
            icon: Icon(themeMode == ThemeMode.dark
                ? Icons.dark_mode_outlined
                : themeMode == ThemeMode.light
                    ? Icons.light_mode_outlined
                    : Icons.brightness_auto_outlined),
            onSelected: (mode) => ref.read(themeModeProvider.notifier).setMode(mode),
            itemBuilder: (context) => const [
              PopupMenuItem(value: ThemeMode.system, child: Text('Automático')),
              PopupMenuItem(value: ThemeMode.light, child: Text('Claro')),
              PopupMenuItem(value: ThemeMode.dark, child: Text('Oscuro')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(),
          const SizedBox(height: 20),
          Text('Practicar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _MenuCard(
            icon: Icons.hub_outlined,
            color: NetVisionColors.cobalt,
            title: 'NetVision Workspace',
            subtitle: 'Sandbox libre: construye y prueba tus propias redes.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkspaceScreen())),
          ),
          _MenuCard(
            icon: Icons.route_outlined,
            color: NetVisionColors.signalYellow,
            title: 'Casos profesionales',
            subtitle: '5 escenarios guiados, incluyendo Network Doctor.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CasesListScreen())),
          ),
          _MenuCard(
            icon: Icons.calculate_outlined,
            color: NetVisionColors.aqua,
            title: 'Taller de subnetting',
            subtitle: 'Divide una red en subredes y visualiza cada bloque.',
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubnettingWorkshopScreen())),
          ),
          const SizedBox(height: 20),
          Text('Seguimiento', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _MenuCard(
            icon: Icons.insights_outlined,
            color: NetVisionColors.titaniumDark,
            title: 'Progreso',
            subtitle: 'Tu dominio por área y estadísticas de práctica.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProgressScreen())),
          ),
          _MenuCard(
            icon: Icons.history_outlined,
            color: NetVisionColors.titaniumDark,
            title: 'Historial',
            subtitle: 'Prácticas anteriores y sus resultados.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
          _MenuCard(
            icon: Icons.menu_book_outlined,
            color: NetVisionColors.titaniumDark,
            title: 'Consulta rápida',
            subtitle: 'Referencia breve de conceptos de redes.',
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuickReferenceScreen())),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [NetVisionColors.cobalt, NetVisionColors.cobaltDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VER LA RED FUNCIONAR',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          SizedBox(height: 8),
          Text(
            'Diseña · Conecta · Configura · Simula · Observa · Diagnostica · Corrige · Verifica',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
