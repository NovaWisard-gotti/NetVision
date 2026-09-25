import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../engine/addressing_engine.dart';
import '../../engine/dhcp_engine.dart';
import '../../engine/dns_engine.dart';
import '../../models/enums.dart';
import '../../models/network_device.dart';
import '../../models/network_scenario.dart';
import '../../state/case_completion_controller.dart';
import '../../state/progress_provider.dart';
import '../../state/workspace_provider.dart';

/// Panel contextual mostrado como hoja inferior al tocar un dispositivo.
/// Muestra únicamente los campos relevantes para ese tipo de dispositivo,
/// evitando formularios gigantes.
class DeviceConfigSheet extends ConsumerStatefulWidget {
  final String deviceId;

  const DeviceConfigSheet({super.key, required this.deviceId});

  @override
  ConsumerState<DeviceConfigSheet> createState() => _DeviceConfigSheetState();
}

class _DeviceConfigSheetState extends ConsumerState<DeviceConfigSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _ipCtrl;
  late TextEditingController _prefixCtrl;
  late TextEditingController _gatewayCtrl;
  late TextEditingController _dnsCtrl;

  String? _error;

  @override
  void initState() {
    super.initState();
    final device = ref.read(workspaceProvider).deviceById(widget.deviceId);
    _nameCtrl = TextEditingController(text: device?.name ?? '');
    final iface = device?.primaryInterface;
    _ipCtrl = TextEditingController(text: iface?.ipv4?.address ?? '');
    _prefixCtrl = TextEditingController(text: (iface?.ipv4?.prefixLength ?? 24).toString());
    _gatewayCtrl = TextEditingController(text: iface?.ipv4?.gateway ?? '');
    _dnsCtrl = TextEditingController(text: iface?.ipv4?.dns ?? '');
  }

  NetworkScenario get _scenario => ref.watch(workspaceProvider);
  NetworkDevice? get _device => _scenario.deviceById(widget.deviceId);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _prefixCtrl.dispose();
    _gatewayCtrl.dispose();
    _dnsCtrl.dispose();
    super.dispose();
  }

  void _applyBasicChanges() {
    final device = _device;
    if (device == null) return;
    final notifier = ref.read(workspaceProvider.notifier);
    notifier.renameDevice(device.id, _nameCtrl.text);

    if (!device.type.supportsIpv4Configuration) return;
    final iface = device.primaryInterface;
    if (iface == null) return;

    final ip = _ipCtrl.text.trim();
    if (ip.isNotEmpty && !AddressingEngine.isValidIpv4(ip)) {
      setState(() => _error = 'La dirección IPv4 no es válida.');
      return;
    }
    final prefix = int.tryParse(_prefixCtrl.text.trim());
    if (prefix == null || !AddressingEngine.isValidPrefix(prefix)) {
      setState(() => _error = 'El prefijo debe ser un número entre 0 y 32.');
      return;
    }
    final gateway = _gatewayCtrl.text.trim();
    if (gateway.isNotEmpty && !AddressingEngine.isValidIpv4(gateway)) {
      setState(() => _error = 'El gateway no es una IPv4 válida.');
      return;
    }
    final dns = _dnsCtrl.text.trim();
    if (dns.isNotEmpty && !AddressingEngine.isValidIpv4(dns)) {
      setState(() => _error = 'El DNS no es una IPv4 válida.');
      return;
    }

    setState(() => _error = null);
    notifier.updateIpv4(
      deviceId: device.id,
      interfaceId: iface.id,
      address: ip,
      prefixLength: prefix,
      gateway: gateway,
      clearGateway: gateway.isEmpty,
      dns: dns,
      clearDns: dns.isEmpty,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración guardada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;
    if (device == null) {
      return const SizedBox.shrink();
    }
    final notifier = ref.read(workspaceProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.32,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NetVisionColors.titanium,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${device.type.label} · ${device.name}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Eliminar dispositivo',
                    icon: const Icon(Icons.delete_outline, color: NetVisionColors.dangerRed),
                    onPressed: () {
                      notifier.removeDevice(device.id);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Conectado a la red'),
                subtitle: Text(device.manuallyDisconnected
                    ? 'Este dispositivo está desconectado manualmente.'
                    : 'El dispositivo está activo.'),
                value: !device.manuallyDisconnected,
                onChanged: (_) {
                  notifier.toggleDeviceConnection(device.id);
                  setState(() {});
                },
              ),
              if (device.type.supportsIpv4Configuration) ...[
                const Divider(height: 28),
                Text('Direccionamiento IPv4', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _ipCtrl,
                        decoration: const InputDecoration(labelText: 'Dirección IPv4'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _prefixCtrl,
                        decoration: const InputDecoration(labelText: 'Prefijo'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (device.type != DeviceType.router)
                  TextField(
                    controller: _gatewayCtrl,
                    decoration: const InputDecoration(labelText: 'Gateway (opcional)'),
                    keyboardType: TextInputType.number,
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _dnsCtrl,
                  decoration: const InputDecoration(labelText: 'DNS (opcional)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                if (device.type != DeviceType.router)
                  Row(
                    children: [
                      const Text('Modo:'),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Estático'),
                        selected: device.primaryInterface?.ipv4?.mode == AddressMode.static,
                        onSelected: (_) {
                          final iface = device.primaryInterface;
                          if (iface == null) return;
                          notifier.updateIpv4(
                              deviceId: device.id, interfaceId: iface.id, mode: AddressMode.static);
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('DHCP'),
                        selected: device.primaryInterface?.ipv4?.mode == AddressMode.dhcp,
                        onSelected: (_) {
                          final iface = device.primaryInterface;
                          if (iface == null) return;
                          notifier.updateIpv4(
                              deviceId: device.id, interfaceId: iface.id, mode: AddressMode.dhcp);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                if (device.type != DeviceType.router &&
                    device.primaryInterface?.ipv4?.mode == AddressMode.dhcp) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.settings_ethernet),
                    label: const Text('Solicitar configuración DHCP'),
                    onPressed: () async {
                      final result = DhcpEngine.requestAddress(
                          scenario: ref.read(workspaceProvider), client: device);
                      var justCompleted = false;
                      if (result.success) {
                        final iface = device.primaryInterface!;
                        notifier.updateIpv4(
                          deviceId: device.id,
                          interfaceId: iface.id,
                          address: result.assignedIp,
                          prefixLength: result.prefixLength,
                          gateway: result.gateway,
                          clearGateway: result.gateway == null,
                          dns: result.dns,
                          clearDns: result.dns == null,
                        );
                        ref.read(progressNotifierProvider.notifier).registerServicePracticed('DHCP');
                        justCompleted = await evaluateAndRegisterCaseCompletion(
                            ref, ref.read(workspaceProvider));
                        if (!mounted) return;
                        setState(() {
                          _ipCtrl.text = result.assignedIp ?? '';
                          _prefixCtrl.text = (result.prefixLength ?? 24).toString();
                          _gatewayCtrl.text = result.gateway ?? '';
                          _dnsCtrl.text = result.dns ?? '';
                        });
                      }
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
                      if (justCompleted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('¡Caso completado! Se actualizó tu progreso.'),
                        ));
                      }
                    },
                  ),
                ],
                if (device.type != DeviceType.router) ...[
                  const SizedBox(height: 8),
                  _DnsLookupTool(deviceId: device.id),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: NetVisionColors.dangerRed)),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _applyBasicChanges,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar configuración'),
                ),
              ],
              if (device.type == DeviceType.server) ...[
                const Divider(height: 28),
                _ServerServicesSection(deviceId: device.id),
              ],
              if (device.type == DeviceType.router) ...[
                const Divider(height: 28),
                _RouterInterfacesSection(deviceId: device.id),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ServerServicesSection extends ConsumerWidget {
  final String deviceId;
  const _ServerServicesSection({required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenario = ref.watch(workspaceProvider);
    final device = scenario.deviceById(deviceId);
    final notifier = ref.read(workspaceProvider.notifier);
    if (device == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Servicios simulados', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Ninguno'),
              selected: device.serverRole == ServerRole.none,
              onSelected: (_) => notifier.updateServerRole(deviceId, ServerRole.none),
            ),
            ChoiceChip(
              label: const Text('DHCP'),
              selected: device.serverRole == ServerRole.dhcp,
              onSelected: (_) => notifier.updateServerRole(deviceId, ServerRole.dhcp),
            ),
            ChoiceChip(
              label: const Text('DNS'),
              selected: device.serverRole == ServerRole.dns,
              onSelected: (_) => notifier.updateServerRole(deviceId, ServerRole.dns),
            ),
            ChoiceChip(
              label: const Text('DHCP + DNS'),
              selected: device.serverRole == ServerRole.dnsAndDhcp,
              onSelected: (_) => notifier.updateServerRole(deviceId, ServerRole.dnsAndDhcp),
            ),
          ],
        ),
        if (device.hasDhcpService) ...[
          const SizedBox(height: 12),
          Text('Pool DHCP', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          _DhcpPoolEditor(deviceId: deviceId),
        ],
        if (device.hasDnsService) ...[
          const SizedBox(height: 12),
          Text('Registros DNS', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          _DnsRecordsEditor(deviceId: deviceId),
        ],
      ],
    );
  }
}

class _DhcpPoolEditor extends ConsumerStatefulWidget {
  final String deviceId;
  const _DhcpPoolEditor({required this.deviceId});

  @override
  ConsumerState<_DhcpPoolEditor> createState() => _DhcpPoolEditorState();
}

class _DhcpPoolEditorState extends ConsumerState<_DhcpPoolEditor> {
  late TextEditingController _start;
  late TextEditingController _end;
  late TextEditingController _prefix;
  late TextEditingController _gw;
  late TextEditingController _dns;

  @override
  void initState() {
    super.initState();
    final d = ref.read(workspaceProvider).deviceById(widget.deviceId);
    _start = TextEditingController(text: d?.dhcpPoolStart ?? '');
    _end = TextEditingController(text: d?.dhcpPoolEnd ?? '');
    _prefix = TextEditingController(text: (d?.dhcpPrefixLength ?? 24).toString());
    _gw = TextEditingController(text: d?.dhcpGateway ?? '');
    _dns = TextEditingController(text: d?.dhcpDns ?? '');
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _prefix.dispose();
    _gw.dispose();
    _dns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: TextField(controller: _start, decoration: const InputDecoration(labelText: 'Desde'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _end, decoration: const InputDecoration(labelText: 'Hasta'))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _prefix, decoration: const InputDecoration(labelText: 'Prefijo'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _gw, decoration: const InputDecoration(labelText: 'Gateway a asignar'))),
        ]),
        const SizedBox(height: 8),
        TextField(controller: _dns, decoration: const InputDecoration(labelText: 'DNS a asignar')),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar pool'),
            onPressed: () {
              final error = ref.read(workspaceProvider.notifier).updateDhcpPool(
                    deviceId: widget.deviceId,
                    start: _start.text.trim(),
                    end: _end.text.trim(),
                    prefixLength: int.tryParse(_prefix.text.trim()),
                    gateway: _gw.text.trim(),
                    dns: _dns.text.trim(),
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error ?? 'Pool DHCP guardado.')),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DnsRecordsEditor extends ConsumerStatefulWidget {
  final String deviceId;
  const _DnsRecordsEditor({required this.deviceId});

  @override
  ConsumerState<_DnsRecordsEditor> createState() => _DnsRecordsEditorState();
}

class _DnsRecordsEditorState extends ConsumerState<_DnsRecordsEditor> {
  final _hostCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(workspaceProvider).deviceById(widget.deviceId);
    if (device == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in device.dnsRecords.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(entry.key),
            subtitle: Text(entry.value),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => ref
                  .read(workspaceProvider.notifier)
                  .removeDnsRecord(widget.deviceId, entry.key),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hostCtrl,
                decoration: const InputDecoration(labelText: 'Nombre (ej. portal.universidad.test)'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ipCtrl,
                decoration: const InputDecoration(labelText: 'IP'),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: const TextStyle(color: NetVisionColors.dangerRed)),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Añadir registro'),
            onPressed: () {
              final hostname = _hostCtrl.text.trim();
              final ip = _ipCtrl.text.trim();
              if (hostname.isEmpty) {
                setState(() => _error = 'Indica el nombre de dominio.');
                return;
              }
              if (!AddressingEngine.isValidIpv4(ip)) {
                setState(() => _error = 'La IP del registro no es una dirección IPv4 válida.');
                return;
              }
              ref.read(workspaceProvider.notifier).setDnsRecord(widget.deviceId, hostname, ip);
              _hostCtrl.clear();
              _ipCtrl.clear();
              setState(() => _error = null);
            },
          ),
        ),
      ],
    );
  }
}

/// Herramienta de "Revisar DNS": el estudiante escribe un nombre de dominio
/// ficticio y ve si el servidor DNS configurado en su cliente logra
/// resolverlo dentro del escenario local.
class _DnsLookupTool extends ConsumerStatefulWidget {
  final String deviceId;
  const _DnsLookupTool({required this.deviceId});

  @override
  ConsumerState<_DnsLookupTool> createState() => _DnsLookupToolState();
}

class _DnsLookupToolState extends ConsumerState<_DnsLookupTool> {
  final _hostCtrl = TextEditingController(text: 'portal.universidad.test');

  @override
  void dispose() {
    _hostCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Revisar DNS (resolución de nombres)'),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hostCtrl,
                decoration: const InputDecoration(labelText: 'Nombre a resolver'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                final scenario = ref.read(workspaceProvider);
                final device = scenario.deviceById(widget.deviceId);
                final clientDns = device?.primaryInterface?.ipv4?.dns;
                final result = DnsEngine.resolve(
                  scenario: scenario,
                  hostname: _hostCtrl.text,
                  clientDeviceId: widget.deviceId,
                  clientDnsIp: clientDns,
                );
                var justCompleted = false;
                if (result.success) {
                  ref.read(progressNotifierProvider.notifier).registerServicePracticed('DNS');
                  justCompleted =
                      await evaluateAndRegisterCaseCompletion(ref, ref.read(workspaceProvider));
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
                if (justCompleted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('¡Caso completado! Se actualizó tu progreso.'),
                  ));
                }
              },
              child: const Text('Resolver'),
            ),
          ],
        ),
      ],
    );
  }
}

class _RouterInterfacesSection extends ConsumerWidget {
  final String deviceId;
  const _RouterInterfacesSection({required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenario = ref.watch(workspaceProvider);
    final device = scenario.deviceById(deviceId);
    if (device == null) return const SizedBox.shrink();
    final notifier = ref.read(workspaceProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Interfaces del router', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final iface in device.interfaces)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _RouterInterfaceRow(deviceId: deviceId, interfaceId: iface.id),
            ),
          ),
        const SizedBox(height: 12),
        Text('Tabla de rutas', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (var i = 0; i < device.routeTable.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
                '${device.routeTable[i]['destinationNetwork']}/${device.routeTable[i]['prefixLength']}'),
            subtitle: Text('Salida: ${device.routeTable[i]['exitInterfaceId']}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => notifier.removeRoute(deviceId, i),
            ),
          ),
        _AddRouteRow(deviceId: deviceId),
      ],
    );
  }
}

class _RouterInterfaceRow extends ConsumerStatefulWidget {
  final String deviceId;
  final String interfaceId;
  const _RouterInterfaceRow({required this.deviceId, required this.interfaceId});

  @override
  ConsumerState<_RouterInterfaceRow> createState() => _RouterInterfaceRowState();
}

class _RouterInterfaceRowState extends ConsumerState<_RouterInterfaceRow> {
  late TextEditingController _ip;
  late TextEditingController _prefix;

  @override
  void initState() {
    super.initState();
    final device = ref.read(workspaceProvider).deviceById(widget.deviceId);
    final iface = device?.interfaces.firstWhere((i) => i.id == widget.interfaceId);
    _ip = TextEditingController(text: iface?.ipv4?.address ?? '');
    _prefix = TextEditingController(text: (iface?.ipv4?.prefixLength ?? 24).toString());
  }

  @override
  void dispose() {
    _ip.dispose();
    _prefix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(workspaceProvider).deviceById(widget.deviceId);
    final iface = device?.interfaces.firstWhere((i) => i.id == widget.interfaceId);
    return Row(
      children: [
        Expanded(child: Text(iface?.name ?? '', style: Theme.of(context).textTheme.labelLarge)),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(controller: _ip, decoration: const InputDecoration(labelText: 'IP')),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: TextField(controller: _prefix, decoration: const InputDecoration(labelText: 'Pref.')),
        ),
        IconButton(
          icon: const Icon(Icons.check, size: 20),
          onPressed: () {
            final address = _ip.text.trim();
            if (address.isNotEmpty && !AddressingEngine.isValidIpv4(address)) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('La dirección IPv4 no es válida.')));
              return;
            }
            final prefix = int.tryParse(_prefix.text.trim());
            if (prefix == null || !AddressingEngine.isValidPrefix(prefix)) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El prefijo debe ser un número entre 0 y 32.')));
              return;
            }
            ref.read(workspaceProvider.notifier).updateIpv4(
                  deviceId: widget.deviceId,
                  interfaceId: widget.interfaceId,
                  address: address,
                  prefixLength: prefix,
                );
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Interfaz actualizada.')));
          },
        ),
      ],
    );
  }
}

class _AddRouteRow extends ConsumerStatefulWidget {
  final String deviceId;
  const _AddRouteRow({required this.deviceId});

  @override
  ConsumerState<_AddRouteRow> createState() => _AddRouteRowState();
}

class _AddRouteRowState extends ConsumerState<_AddRouteRow> {
  final _net = TextEditingController();
  final _prefix = TextEditingController(text: '24');
  String? _exitIface;

  @override
  void dispose() {
    _net.dispose();
    _prefix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(workspaceProvider).deviceById(widget.deviceId);
    if (device == null) return const SizedBox.shrink();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _net,
                decoration: const InputDecoration(labelText: 'Red destino'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: TextField(
                controller: _prefix,
                decoration: const InputDecoration(labelText: 'Pref.'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _exitIface,
          decoration: const InputDecoration(labelText: 'Interfaz de salida'),
          items: device.interfaces
              .map((i) => DropdownMenuItem(value: i.id, child: Text(i.name)))
              .toList(),
          onChanged: (v) => setState(() => _exitIface = v),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Añadir ruta'),
            onPressed: () {
              if (_net.text.trim().isEmpty || _exitIface == null) return;
              final error = ref.read(workspaceProvider.notifier).addRoute(
                    routerId: widget.deviceId,
                    destinationNetwork: _net.text.trim(),
                    prefixLength: int.tryParse(_prefix.text.trim()) ?? -1,
                    exitInterfaceId: _exitIface!,
                  );
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                return;
              }
              _net.clear();
              setState(() => _exitIface = null);
            },
          ),
        ),
      ],
    );
  }
}
