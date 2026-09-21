# NetVision

**Laboratorio visual de redes para estudiantes universitarios de Ingeniería de Sistemas.**

NetVision es una aplicación móvil educativa (Flutter/Android) del proyecto *Educational Mobile
Apps Factory*. Su identidad central es **ver la red funcionar**: el estudiante diseña una
topología, la conecta, la configura, simula el envío de paquetes y diagnostica fallas reales
—todo dentro de un motor de simulación local, sin tocar redes reales.

```
DISEÑAR RED → CONFIGURAR → TRANSMITIR → VISUALIZAR → DIAGNOSTICAR → CORREGIR
```

---

## 1. Estado de este entrega

Este repositorio contiene el **código fuente completo del MVP**: modelos, motores de
simulación/direccionamiento IPv4/DHCP/DNS/diagnóstico, estado (Riverpod), persistencia local y
todas las pantallas descritas en el alcance del MVP. No se dejaron pantallas placeholder,
botones sin acción ni TODOs.

> **Nota honesta sobre compilación:** este código fue escrito y revisado cuidadosamente a mano,
> pero no fue compilado dentro del entorno donde se generó (no cuenta con el SDK de Flutter/
> Android ni acceso a pub.dev). El workflow de GitHub Actions incluido (`.github/workflows/
> build.yml`) compila automáticamente los APK de depuración y de release apenas se sube el
> repositorio a GitHub — es la forma recomendada de obtener el primer build verificado. Si
> aparece algún error de compilación puntual (por ejemplo, por una API de Flutter que cambió de
> nombre entre versiones), la corrección debería ser localizada y rápida: la arquitectura,
> los modelos y la lógica de los motores son independientes del framework de UI y no deberían
> verse afectados.

## 2. Cómo obtener el APK

### Opción A — GitHub Actions (recomendada)
1. Sube este proyecto a un repositorio de GitHub.
2. El workflow `Build NetVision APK` se ejecuta automáticamente en cada `push` a `main` (o
   manualmente desde la pestaña *Actions* → *Run workflow*).
3. Descarga el artefacto `netvision-release-apk` (o `netvision-debug-apk`) generado.

### Opción B — Local
Requiere tener instalado el SDK de Flutter (canal *stable*) y el SDK de Android.

```bash
flutter pub get
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.

El nombre visible de la app, una vez instalada, es exactamente **NetVision** (`android:label`
en `android/app/src/main/AndroidManifest.xml`), con un ícono launcher propio (`assets/icon/
app_icon.png`, generado específicamente para este proyecto, conceptualmente distinto de
ArchFlow/HackZone/LogicAI).

## 3. Arquitectura

```
INTERFAZ (lib/ui)
   ↓
ESTADO (lib/state — Riverpod: StateNotifierProvider por responsabilidad)
   ↓
MOTOR DE SIMULACIÓN (lib/engine/simulation_engine.dart)
MOTOR DE DIRECCIONAMIENTO (lib/engine/addressing_engine.dart)
MOTOR DHCP / DNS / DIAGNÓSTICO (lib/engine/*)
   ↓
PERSISTENCIA (lib/persistence — shared_preferences, JSON local)
```

- **`lib/models/`** — Entidades puras: `NetworkDevice`, `NetworkInterface`, `NetworkLink`,
  `Ipv4Configuration`, `NetworkScenario`, `SimulatedPacket`/`PacketHop`, `DiagnosticIssue`,
  `HistoryEntry`, `ProgressStats`.
- **`lib/engine/`** — Toda la lógica de red vive aquí, nunca en los widgets:
  - `AddressingEngine`: validación IPv4, cálculo de red/broadcast/rango de hosts,
    comparación de subredes, división en subredes (subnetting).
  - `SimulationEngine`: determina —a partir del estado real de la topología, nunca con
    animaciones predefinidas— si dos dispositivos pueden comunicarse, con recorrido (Packet
    Journey) salto a salto, incluyendo ARP conceptual, decisión de gateway y tabla de rutas
    entre routers.
  - `DhcpEngine` / `DnsEngine`: asignación DHCP y resolución DNS simuladas.
  - `DiagnosticsEngine`: validación de topología (IP inválida, duplicada, gateway
    incompatible, dispositivo aislado, enlace deshabilitado, etc.).
- **`lib/state/`** — Providers Riverpod: Workspace (CRUD de topología), Packet Journey
  (reproducción paso a paso), progreso, historial, tema, casos.
- **`lib/persistence/`** — `LocalStorageService`: todo el guardado es local (sandbox, casos en
  progreso, historial, progreso, preferencia de tema). Las topologías se serializan completas
  (nunca como imágenes) para poder reabrirse y editarse.
- **`lib/ui/`** — Pantallas y widgets. El NetVision Workspace (`workspace_screen.dart` +
  `workspace_canvas.dart`) es el lienzo compartido por el sandbox libre y los casos guiados
  (incluyendo Network Doctor, activado cuando el caso trae una falla oculta).

## 4. Alcance funcional cubierto

- NetVision Workspace: añadir/mover/eliminar dispositivos (PC, laptop, servidor, switch,
  router, punto de acceso), conectar/desconectar, zoom y paneo.
- Configuración IPv4 completa por dispositivo (estático o DHCP), gateway, DNS.
- Taller de subnetting con visualizador de direcciones (red / hosts / broadcast).
- Packet Journey: recorrido real salto a salto, reproducción automática y paso a paso,
  reinicio, y modo "¿Dónde se detuvo?" cuando la comunicación falla.
- Ping educativo ("Probar conectividad") con resumen de recorrido y causa del fallo.
- DHCP simulado (pool, asignación) y DNS simulado (registros, resolución) mediante servidores
  configurables.
- Tabla de rutas simplificada en routers (redes directamente conectadas + rutas estáticas).
- Network Doctor: casos con falla oculta, pistas progresivas y verificación de la solución.
- Validación de topología (IP inválida/duplicada, gateway incompatible, dispositivo aislado,
  enlace deshabilitado, configuración incompleta).
- Cinco casos profesionales completos y jugables desde el inicio.
- Sandbox libre con límite de dispositivos para estabilidad.
- Informe educativo, historial y progreso (sin monedas, XP, vidas ni rankings).
- Consulta rápida de conceptos.
- Persistencia local completa y funcionamiento 100% offline (sin permisos de INTERNET en el
  build de release).
- Modo claro y oscuro con paleta propia (azul cobalto, aguamarina, gris titanio, blanco
  mineral, amarillo señal).

## 5. Fuera de alcance (según especificación)

CLI/Cisco IOS, Packet Tracer/GNS3, tráfico real, Wireshark, escaneo de redes reales, OSPF/BGP/
MPLS/VPN/SDN, IPv6 avanzado, IA obligatoria, backend remoto.

## 6. Estructura del proyecto

```
lib/
  core/theme/          Paleta e identidad visual (claro/oscuro)
  models/              Entidades de dominio
  engine/              Lógica de red (sin dependencias de Flutter UI)
  persistence/         Almacenamiento local (shared_preferences)
  state/               Providers Riverpod
  data/                Casos profesionales y contenido de consulta rápida
  ui/screens/          Pantallas
  ui/widgets/          Widgets reutilizables (canvas, nodo, paneles, diálogos)
test/                  Pruebas unitarias del motor de direccionamiento
android/               Proyecto Android nativo (Gradle)
assets/icon/           Ícono original de la app
.github/workflows/     CI/CD (build automático de APK)
```
