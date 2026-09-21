import 'package:flutter/material.dart';
import '../../models/network_device.dart';
import '../../models/network_scenario.dart';
import 'device_node_widget.dart';
import 'link_painter.dart';

/// Tamaño lógico del lienzo del NetVision Workspace. Las posiciones de los
/// dispositivos ([NetworkDevice.position]) se expresan en este sistema de
/// coordenadas, independientemente del zoom/paneo aplicado por
/// [InteractiveViewer].
const Size kCanvasSize = Size(1100, 900);

/// Lienzo visual reutilizable: se usa tanto en el NetVision Workspace
/// (editable, con arrastre de dispositivos) como en Packet Journey y
/// Network Doctor (modo solo lectura, con resaltado de ruta/fallas).
class WorkspaceCanvas extends StatefulWidget {
  final NetworkScenario scenario;
  final bool editable;
  final String? selectedDeviceId;
  final String? pendingConnectionSourceId;
  final Set<String> highlightedDeviceIds;
  final String? failureDeviceId;
  final Set<String> highlightedLinkKeys;
  final void Function(String deviceId)? onDeviceTap;
  final void Function(String deviceId, Offset newPosition)? onDeviceMoved;
  final Widget? overlayMarker; // p.ej. el paquete animado de Packet Journey
  final Offset? overlayMarkerPosition;

  const WorkspaceCanvas({
    super.key,
    required this.scenario,
    this.editable = true,
    this.selectedDeviceId,
    this.pendingConnectionSourceId,
    this.highlightedDeviceIds = const {},
    this.failureDeviceId,
    this.highlightedLinkKeys = const {},
    this.onDeviceTap,
    this.onDeviceMoved,
    this.overlayMarker,
    this.overlayMarkerPosition,
  });

  @override
  State<WorkspaceCanvas> createState() => _WorkspaceCanvasState();
}

class _WorkspaceCanvasState extends State<WorkspaceCanvas> {
  final TransformationController _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _currentScale => _controller.value.getMaxScaleOnAxis();

  @override
  Widget build(BuildContext context) {
    final devicesById = {for (final d in widget.scenario.devices) d.id: d};

    return InteractiveViewer(
      transformationController: _controller,
      constrained: false,
      minScale: 0.4,
      maxScale: 2.2,
      boundaryMargin: const EdgeInsets.all(200),
      child: SizedBox(
        width: kCanvasSize.width,
        height: kCanvasSize.height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: LinkPainter(
                  links: widget.scenario.links,
                  devicesById: devicesById,
                  highlightedLinkKeys: widget.highlightedLinkKeys,
                ),
              ),
            ),
            for (final device in widget.scenario.devices)
              Positioned(
                left: device.position.dx,
                top: device.position.dy,
                child: _buildNode(device),
              ),
            if (widget.overlayMarker != null && widget.overlayMarkerPosition != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOut,
                left: widget.overlayMarkerPosition!.dx,
                top: widget.overlayMarkerPosition!.dy,
                child: widget.overlayMarker!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNode(NetworkDevice device) {
    final node = DeviceNodeWidget(
      device: device,
      isSelected: widget.selectedDeviceId == device.id,
      isPendingConnectionSource: widget.pendingConnectionSourceId == device.id,
      isHighlighted: widget.highlightedDeviceIds.contains(device.id),
      isFailureHighlight: widget.failureDeviceId == device.id,
      onTap: () => widget.onDeviceTap?.call(device.id),
    );

    if (!widget.editable) return node;

    return GestureDetector(
      onPanUpdate: (details) {
        final scale = _currentScale == 0 ? 1.0 : _currentScale;
        final delta = details.delta / scale;
        final newPos = device.position + delta;
        widget.onDeviceMoved?.call(device.id, newPos);
      },
      child: node,
    );
  }
}
