import 'network_device.dart';
import 'network_link.dart';

/// Un caso profesional o una topología guardada (incluye el sandbox libre).
class NetworkScenario {
  final String id;
  String title;
  String objective;
  List<NetworkDevice> devices;
  List<NetworkLink> links;
  final bool isBuiltInCase;
  final int? caseNumber;

  /// Si el escenario es un caso de Network Doctor, describe la falla oculta
  /// para poder validar cuando el estudiante la corrija (no se muestra al
  /// estudiante hasta que resuelva o pida ayuda).
  final String? hiddenFaultDescription;

  /// Para escenarios de Network Doctor: el par origen/destino cuya
  /// comunicación debería fallar inicialmente y tener éxito una vez
  /// corregida la falla.
  final String? testSourceDeviceId;
  final String? testDestinationDeviceId;

  NetworkScenario({
    required this.id,
    required this.title,
    required this.objective,
    List<NetworkDevice>? devices,
    List<NetworkLink>? links,
    this.isBuiltInCase = false,
    this.caseNumber,
    this.hiddenFaultDescription,
    this.testSourceDeviceId,
    this.testDestinationDeviceId,
  })  : devices = devices ?? [],
        links = links ?? [];

  NetworkDevice? deviceById(String id) {
    for (final d in devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'objective': objective,
        'devices': devices.map((d) => d.toJson()).toList(),
        'links': links.map((l) => l.toJson()).toList(),
        'isBuiltInCase': isBuiltInCase,
        'caseNumber': caseNumber,
        'hiddenFaultDescription': hiddenFaultDescription,
        'testSourceDeviceId': testSourceDeviceId,
        'testDestinationDeviceId': testDestinationDeviceId,
      };

  factory NetworkScenario.fromJson(Map<String, dynamic> json) {
    return NetworkScenario(
      id: json['id'] as String,
      title: json['title'] as String,
      objective: json['objective'] as String,
      devices: (json['devices'] as List<dynamic>? ?? [])
          .map((e) => NetworkDevice.fromJson(e as Map<String, dynamic>))
          .toList(),
      links: (json['links'] as List<dynamic>? ?? [])
          .map((e) => NetworkLink.fromJson(e as Map<String, dynamic>))
          .toList(),
      isBuiltInCase: json['isBuiltInCase'] as bool? ?? false,
      caseNumber: json['caseNumber'] as int?,
      hiddenFaultDescription: json['hiddenFaultDescription'] as String?,
      testSourceDeviceId: json['testSourceDeviceId'] as String?,
      testDestinationDeviceId: json['testDestinationDeviceId'] as String?,
    );
  }

  /// Crea una copia profunda independiente de este escenario (útil para
  /// abrir un caso guiado sin mutar la plantilla original, o para guardar
  /// una instantánea en el historial).
  NetworkScenario deepCopy({String? newId}) {
    final json = toJson();
    if (newId != null) {
      json['id'] = newId;
    }
    return NetworkScenario.fromJson(json);
  }
}
