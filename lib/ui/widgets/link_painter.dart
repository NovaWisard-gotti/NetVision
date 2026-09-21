import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/network_device.dart';
import '../../models/network_link.dart';
import 'device_node_widget.dart';

/// Dibuja las conexiones entre dispositivos como líneas dentro del canvas.
///
/// Las conexiones deshabilitadas se dibujan punteadas y en gris para dejar
/// claro que un paquete no puede atravesarlas.
class LinkPainter extends CustomPainter {
  final List<NetworkLink> links;
  final Map<String, NetworkDevice> devicesById;
  final Set<String> highlightedLinkKeys; // "deviceA|deviceB" en cualquier orden

  LinkPainter({
    required this.links,
    required this.devicesById,
    this.highlightedLinkKeys = const {},
  });

  Offset _center(NetworkDevice d) =>
      d.position + const Offset(kNodeSize / 2 + 12, kNodeSize / 2);

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in links) {
      final a = devicesById[link.deviceAId];
      final b = devicesById[link.deviceBId];
      if (a == null || b == null) continue;

      final key1 = '${link.deviceAId}|${link.deviceBId}';
      final key2 = '${link.deviceBId}|${link.deviceAId}';
      final isHighlighted =
          highlightedLinkKeys.contains(key1) || highlightedLinkKeys.contains(key2);

      final paint = Paint()
        ..strokeWidth = isHighlighted ? 4.5 : 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (!link.enabled) {
        paint.color = NetVisionColors.dangerRed.withValues(alpha: 0.7);
        _drawDashedLine(canvas, _center(a), _center(b), paint);
      } else if (isHighlighted) {
        paint.color = NetVisionColors.signalYellow;
        canvas.drawLine(_center(a), _center(b), paint);
      } else {
        paint.color = NetVisionColors.titanium;
        canvas.drawLine(_center(a), _center(b), paint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final total = (p2 - p1).distance;
    final direction = (p2 - p1) / total;
    var distance = 0.0;
    while (distance < total) {
      final segmentEnd = (distance + dashWidth) > total ? total : (distance + dashWidth);
      final start = p1 + direction * distance;
      final end = p1 + direction * segmentEnd;
      canvas.drawLine(start, end, paint);
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant LinkPainter oldDelegate) {
    return oldDelegate.links != links ||
        oldDelegate.devicesById != devicesById ||
        oldDelegate.highlightedLinkKeys != highlightedLinkKeys;
  }
}
