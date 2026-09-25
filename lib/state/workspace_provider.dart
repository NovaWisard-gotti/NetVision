import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../engine/addressing_engine.dart';
import '../engine/dhcp_engine.dart';
import '../models/enums.dart';
import '../models/ipv4_configuration.dart';
import '../models/network_device.dart';
import '../models/network_interface.dart';
import '../models/network_link.dart';
import '../models/network_scenario.dart';
import 'storage_provider.dart';

const _uuid = Uuid();

/// Límite máximo de dispositivos en el sandbox libre para garantizar
/// estabilidad y una buena experiencia móvil (regla del proyecto: no
/// permitir topologías gigantes).
const int kMaxSandboxDevices = 10;

/// Notifier que administra la topología que el estudiante está editando
/// actualmente en el NetVision Workspace (puede ser el sandbox libre o un
/// caso profesional en curso).
class WorkspaceNotifier extends StateNotifier<NetworkScenario> {
  final Ref ref;
  bool isSandbox;

  WorkspaceNotifier(this.ref, NetworkScenario initial, {this.isSandbox = true})
      : super(initial);

  void loadScenario(NetworkScenario scenario, {required bool sandbox}) {
    isSandbox = sandbox;
    state = scenario;
  }

  void _persistIfSandbox() {
    if (isSandbox) {
      ref.read(storageServiceProvider).saveSandbox(state);
    } else {
      // Los casos profesionales en curso también se persisten (por id) para
      // poder continuar prácticas incompletas desde la lista de casos.
      ref.read(storageServiceProvider).upsertScenario(state);
    }
  }

  int get deviceLimit => isSandbox ? kMaxSandboxDevices : 14;

  String _defaultNameFor(DeviceType type, NetworkScenario scenario) {
    final countOfType =
        scenario.devices.where((d) => d.type == type).length + 1;
    switch (type) {
      case DeviceType.pc:
        return 'PC-$countOfType';
      case DeviceType.laptop:
        return 'Laptop-$countOfType';
      case DeviceType.server:
        return 'Servidor-$countOfType';
      case DeviceType.switchDevice:
        return 'Switch-$countOfType';
      case DeviceType.router:
        return 'Router-$countOfType';
      case DeviceType.accessPoint:
        return 'AP-$countOfType';
    }
  }

  /// Añade un dispositivo nuevo en [position]. Devuelve un mensaje de error
  /// si se alcanzó el límite, o null si tuvo éxito.
  String? addDevice(DeviceType type, Offset position) {
    if (state.devices.length >= deviceLimit) {
      return 'Se alcanzó el límite de $deviceLimit dispositivos para mantener una buena experiencia móvil.';
    }
    final id = _uuid.v4();
    final device = NetworkDevice(
      id: id,
      type: type,
      name: _defaultNameFor(type, state),
      position: position,
    );

    if (type.isMultiInterface) {
      device.interfaces.add(NetworkInterface(
        id: _uuid.v4(),
        deviceId: id,
        name: 'Interfaz 1',
        ipv4: Ipv4Configuration.empty(),
      ));
    } else if (type.supportsIpv4Configuration) {
      device.interfaces.add(NetworkInterface(
        id: _uuid.v4(),
        deviceId: id,
        name: 'Interfaz',
        ipv4: Ipv4Configuration.empty(),
      ));
    } else {
      // Switch / AP: puertos sin IP, se crean bajo demanda al conectar.
    }

    state = state.copyWith(devices: [...state.devices, device]);
    _persistIfSandbox();
    return null;
  }

  void moveDevice(String deviceId, Offset newPosition) {
    final device = state.deviceById(deviceId);
    if (device == null) return;
    device.position = newPosition;
    state = NetworkScenario.fromJson(state.toJson()); // fuerza notificación
    _persistIfSandbox();
  }

  void renameDevice(String deviceId, String newName) {
    final device = state.deviceById(deviceId);
    if (device == null || newName.trim().isEmpty) return;
    device.name = newName.trim();
    _touch();
  }

  void removeDevice(String deviceId) {
    final devices = state.devices.where((d) => d.id != deviceId).toList();
    final links =
        state.links.where((l) => !l.connects(deviceId)).toList();
    state = state.copyWith(devices: devices, links: links);
    _persistIfSandbox();
  }

  void toggleDeviceConnection(String deviceId) {
    final device = state.deviceById(deviceId);
    if (device == null) return;
    device.manuallyDisconnected = !device.manuallyDisconnected;
    _touch();
  }

  /// Crea o encuentra una interfaz disponible en un switch/AP para poder
  /// conectarlo (los relays de capa 2 generan puertos bajo demanda).
  NetworkInterface _ensurePortForRelay(NetworkDevice device) {
    final freePort = device.interfaces.firstWhere(
      (i) => !state.links.any((l) => l.interfaceAId == i.id || l.interfaceBId == i.id),
      orElse: () => NetworkInterface(
        id: _uuid.v4(),
        deviceId: device.id,
        name: 'Puerto ${device.interfaces.length + 1}',
      ),
    );
    if (!device.interfaces.any((i) => i.id == freePort.id)) {
      device.interfaces.add(freePort);
    }
    return freePort;
  }

  /// Conecta dos dispositivos. Para hosts/routers se usa su interfaz
  /// principal (o se crea una nueva interfaz en el router si ya tiene la
  /// principal ocupada). Para switches/AP se reserva un puerto libre.
  String? connectDevices(String deviceAId, String deviceBId) {
    if (deviceAId == deviceBId) return 'Un dispositivo no puede conectarse a sí mismo.';
    final deviceA = state.deviceById(deviceAId);
    final deviceB = state.deviceById(deviceBId);
    if (deviceA == null || deviceB == null) return 'Dispositivo no encontrado.';

    final alreadyLinked = state.links.any((l) =>
        (l.deviceAId == deviceAId && l.deviceBId == deviceBId) ||
        (l.deviceAId == deviceBId && l.deviceBId == deviceAId));
    if (alreadyLinked) return 'Estos dispositivos ya están conectados.';

    final ifaceA = _resolveInterfaceForConnection(deviceA);
    final ifaceB = _resolveInterfaceForConnection(deviceB);
    if (ifaceA == null) return '${deviceA.name} no tiene interfaces disponibles para conectar.';
    if (ifaceB == null) return '${deviceB.name} no tiene interfaces disponibles para conectar.';

    final link = NetworkLink(
      id: _uuid.v4(),
      deviceAId: deviceAId,
      interfaceAId: ifaceA.id,
      deviceBId: deviceBId,
      interfaceBId: ifaceB.id,
    );
    state = state.copyWith(links: [...state.links, link]);
    _persistIfSandbox();
    return null;
  }

  NetworkInterface? _resolveInterfaceForConnection(NetworkDevice device) {
    if (device.type.isLayer2Relay) {
      return _ensurePortForRelay(device);
    }
    if (device.type.isMultiInterface) {
      // Router: usa una interfaz libre existente, o crea una nueva si todas
      // las actuales ya están enlazadas.
      final freeIface = device.interfaces.firstWhere(
        (i) => !state.links.any((l) => l.interfaceAId == i.id || l.interfaceBId == i.id),
        orElse: () => NetworkInterface(
          id: _uuid.v4(),
          deviceId: device.id,
          name: 'Interfaz ${device.interfaces.length + 1}',
          ipv4: Ipv4Configuration.empty(),
        ),
      );
      if (!device.interfaces.any((i) => i.id == freeIface.id)) {
        device.interfaces.add(freeIface);
      }
      return freeIface;
    }
    // Host normal: una sola interfaz principal, reutilizable (un host solo
    // puede tener un cable activo en el alcance del MVP).
    if (device.interfaces.isEmpty) {
      final iface = NetworkInterface(
        id: _uuid.v4(),
        deviceId: device.id,
        name: 'Interfaz',
        ipv4: Ipv4Configuration.empty(),
      );
      device.interfaces.add(iface);
      return iface;
    }
    final alreadyConnected = state.links.any((l) =>
        l.interfaceAId == device.interfaces.first.id ||
        l.interfaceBId == device.interfaces.first.id);
    if (alreadyConnected) return null;
    return device.interfaces.first;
  }

  void removeLink(String linkId) {
    state = state.copyWith(links: state.links.where((l) => l.id != linkId).toList());
    _persistIfSandbox();
  }

  void toggleLink(String linkId) {
    final link = state.links.firstWhere((l) => l.id == linkId);
    link.enabled = !link.enabled;
    _touch();
  }

  void updateIpv4({
    required String deviceId,
    required String interfaceId,
    String? address,
    int? prefixLength,
    String? gateway,
    bool clearGateway = false,
    String? dns,
    bool clearDns = false,
    AddressMode? mode,
  }) {
    final device = state.deviceById(deviceId);
    if (device == null) return;
    final iface = device.interfaces.firstWhere((i) => i.id == interfaceId);
    final current = iface.ipv4 ?? Ipv4Configuration.empty();
    iface.ipv4 = current.copyWith(
      address: address,
      prefixLength: prefixLength,
      gateway: gateway,
      clearGateway: clearGateway,
      dns: dns,
      clearDns: clearDns,
      mode: mode,
    );
    _touch();
  }

  void updateServerRole(String deviceId, ServerRole role) {
    final device = state.deviceById(deviceId);
    if (device == null) return;
    device.serverRole = role;
    _touch();
  }

  /// Valida y guarda el pool DHCP de un servidor. Devuelve un mensaje de
  /// error (y no guarda nada) si la configuración es inválida, o `null` si
  /// se guardó correctamente.
  String? updateDhcpPool({
    required String deviceId,
    String? start,
    String? end,
    int? prefixLength,
    String? gateway,
    String? dns,
  }) {
    final device = state.deviceById(deviceId);
    if (device == null) return 'Dispositivo no encontrado.';

    final effectiveStart = start ?? device.dhcpPoolStart;
    final effectiveEnd = end ?? device.dhcpPoolEnd;
    final effectivePrefix = prefixLength ?? device.dhcpPrefixLength;
    final effectiveGateway = gateway ?? device.dhcpGateway;
    final effectiveDns = dns ?? device.dhcpDns;

    final error = DhcpEngine.validatePool(
      start: effectiveStart,
      end: effectiveEnd,
      prefixLength: effectivePrefix,
      gateway: effectiveGateway,
      dns: effectiveDns,
    );
    if (error != null) return error;

    device.dhcpPoolStart = effectiveStart;
    device.dhcpPoolEnd = effectiveEnd;
    device.dhcpPrefixLength = effectivePrefix;
    device.dhcpGateway = effectiveGateway;
    device.dhcpDns = effectiveDns;
    _touch();
    return null;
  }

  void setDnsRecord(String deviceId, String hostname, String ip) {
    final device = state.deviceById(deviceId);
    if (device == null) return;
    device.dnsRecords[hostname.trim().toLowerCase()] = ip.trim();
    _touch();
  }

  void removeDnsRecord(String deviceId, String hostname) {
    final device = state.deviceById(deviceId);
    if (device == null) return;
    device.dnsRecords.remove(hostname.trim().toLowerCase());
    _touch();
  }

  /// Valida y agrega una ruta estática. Devuelve un mensaje de error (y no
  /// guarda nada) si los datos son inválidos, o `null` si se guardó
  /// correctamente.
  String? addRoute({
    required String routerId,
    required String destinationNetwork,
    required int prefixLength,
    required String exitInterfaceId,
  }) {
    final device = state.deviceById(routerId);
    if (device == null) return 'Router no encontrado.';

    if (!AddressingEngine.isValidIpv4(destinationNetwork)) {
      return 'La red destino no es una dirección IPv4 válida.';
    }
    if (!AddressingEngine.isValidPrefix(prefixLength)) {
      return 'El prefijo debe estar entre 0 y 32.';
    }
    final exitIface = device.interfaces.where((i) => i.id == exitInterfaceId);
    if (exitIface.isEmpty) {
      return 'La interfaz de salida seleccionada no existe en este router.';
    }

    final normalizedNetwork = AddressingEngine.networkAddress(destinationNetwork, prefixLength);
    device.routeTable.add({
      'destinationNetwork': normalizedNetwork,
      'prefixLength': prefixLength,
      'exitInterfaceId': exitInterfaceId,
    });
    _touch();
    return null;
  }

  void removeRoute(String routerId, int index) {
    final device = state.deviceById(routerId);
    if (device == null) return;
    if (index >= 0 && index < device.routeTable.length) {
      device.routeTable.removeAt(index);
    }
    _touch();
  }

  void _touch() {
    state = NetworkScenario.fromJson(state.toJson());
    _persistIfSandbox();
  }
}

/// Escenario vacío inicial usado antes de que se cargue el sandbox
/// persistido (o mientras se abre un caso).
NetworkScenario emptyScenario({String title = 'Mi red', String objective = ''}) =>
    NetworkScenario(id: _uuid.v4(), title: title, objective: objective);

final workspaceProvider =
    StateNotifierProvider<WorkspaceNotifier, NetworkScenario>((ref) {
  final storage = ref.read(storageServiceProvider);
  final saved = storage.loadSandbox();
  return WorkspaceNotifier(ref, saved ?? emptyScenario(), isSandbox: true);
});

/// Dispositivo actualmente seleccionado en el Workspace (para abrir su
/// panel de configuración).
final selectedDeviceIdProvider = StateProvider<String?>((ref) => null);

/// Modo de conexión activo: cuando no es null, el próximo toque sobre un
/// dispositivo intentará conectar ese dispositivo con el almacenado aquí.
final pendingConnectionSourceProvider = StateProvider<String?>((ref) => null);
