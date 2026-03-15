import '../models/activity.dart';

/// Generates Google Static Maps API URLs from a GPS route.
/// Requires a valid API key in lib/config/api_keys.dart.
class StaticMapHelper {
  /// Build a thumbnail URL (for activity feed cards).
  static String buildThumbnailUrl({
    required List<GpsPoint> points,
    required String apiKey,
    int width = 800,
    int height = 200,
  }) {
    return _build(
      points: points,
      apiKey: apiKey,
      width: width,
      height: height,
      zoom: null, // auto-fit to path
      lineColor: '0x7BAF1Eff',
      lineWeight: 3,
    );
  }

  /// Build a full-size map URL (for activity detail screen).
  static String buildDetailUrl({
    required List<GpsPoint> points,
    required String apiKey,
    int width = 800,
    int height = 400,
  }) {
    return _build(
      points: points,
      apiKey: apiKey,
      width: width,
      height: height,
      zoom: null,
      lineColor: '0x7BAF1Eff',
      lineWeight: 4,
    );
  }

  // ---------------------------------------------------------------------------

  static String _build({
    required List<GpsPoint> points,
    required String apiKey,
    required int width,
    required int height,
    int? zoom,
    required String lineColor,
    required int lineWeight,
  }) {
    if (apiKey.isEmpty || apiKey == 'YOUR_API_KEY_HERE') return '';
    if (points.isEmpty) return '';

    // Downsample so the URL doesn't exceed ~2 KB
    final sampled = _sample(points, 80);
    final pathPoints = sampled.map((p) => '${p.lat},${p.lng}').join('|');

    final buffer = StringBuffer(
        'https://maps.googleapis.com/maps/api/staticmap?');

    buffer.write('size=${width}x$height');
    buffer.write('&scale=2'); // retina / hi-dpi
    buffer.write('&maptype=roadmap');
    // Light style to match the app's green theme
    buffer.write(
        '&style=feature:water%7Celement:geometry%7Ccolor:0xd4ecf7');
    buffer.write(
        '&style=feature:landscape%7Celement:geometry%7Ccolor:0xf2f2ee');
    buffer.write(
        '&style=feature:road%7Celement:geometry%7Ccolor:0xffffff');
    buffer.write(
        '&style=feature:poi%7Cvisibility:off');
    buffer.write(
        '&path=color:$lineColor%7Cweight:$lineWeight%7C$pathPoints');
    if (zoom != null) buffer.write('&zoom=$zoom');
    buffer.write('&key=$apiKey');

    return buffer.toString();
  }

  /// Reduce a list to at most [max] evenly-spaced elements.
  static List<T> _sample<T>(List<T> list, int max) {
    if (list.length <= max) return list;
    final step = list.length / max;
    return List.generate(
      max,
      (i) => list[(i * step).round().clamp(0, list.length - 1)],
    );
  }
}
