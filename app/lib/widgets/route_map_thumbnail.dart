import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../config/api_keys.dart';
import '../utils/static_map_helper.dart';
import '../main.dart';

/// Shows a real Google Static Map tile with the route drawn on top.
/// Falls back to a simple route-shape painter if no API key is set.
class RouteMapThumbnail extends StatelessWidget {
  final List<GpsPoint> points;
  final bool isDetailView; // true = taller, full-width map
  final double height;
  final BorderRadius borderRadius;

  const RouteMapThumbnail({
    super.key,
    required this.points,
    this.isDetailView = false,
    this.height = 72,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    final url = isDetailView
        ? StaticMapHelper.buildDetailUrl(
            points: points, apiKey: kGoogleMapsApiKey)
        : StaticMapHelper.buildThumbnailUrl(
            points: points, apiKey: kGoogleMapsApiKey);

    if (url.isEmpty) {
      // No API key yet — show route-shape fallback
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.greenLight,
          borderRadius: borderRadius,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: CustomPaint(
            size: Size.infinite,
            painter: _FallbackRoutePainter(points),
          ),
        ),
      );
    }

    // Real Google Static Map
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            color: AppTheme.greenLight,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.greenLight,
            borderRadius: borderRadius,
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: CustomPaint(
              size: Size.infinite,
              painter: _FallbackRoutePainter(points),
            ),
          ),
        ),
      ),
    );
  }
}

// Simple route-outline painter used when the API key is not configured
class _FallbackRoutePainter extends CustomPainter {
  final List<GpsPoint> pts;
  const _FallbackRoutePainter(this.pts);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final lats = pts.map((p) => p.lat).toList();
    final lngs = pts.map((p) => p.lng).toList();
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);
    final dLat = maxLat - minLat;
    final dLng = maxLng - minLng;
    if (dLat == 0 && dLng == 0) return;

    final pad = 12.0;

    Offset toOffset(GpsPoint p) {
      final x = dLng == 0
          ? size.width / 2
          : pad + (p.lng - minLng) / dLng * (size.width - pad * 2);
      final y = dLat == 0
          ? size.height / 2
          : size.height - pad - (p.lat - minLat) / dLat * (size.height - pad * 2);
      return Offset(x, y);
    }

    final paint = Paint()
      ..color = AppTheme.greenDark
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(toOffset(pts.first).dx, toOffset(pts.first).dy);
    for (final p in pts.skip(1)) {
      final o = toOffset(p);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, paint);

    // Start dot
    canvas.drawCircle(toOffset(pts.first), 4,
        Paint()..color = AppTheme.greenDark);
    // End dot
    canvas.drawCircle(toOffset(pts.last), 4,
        Paint()..color = const Color(0xFFE53935));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
