import 'dart:math' as math;
import 'dart:ui';

/// Polygon geometry (meters), same rules as the backend (backend/src/utils/geometry.js).
/// A polygon is a list of points, not closed (the last point is linked to the first one).
class Geometry {
  Geometry._();

  static const double _eps = 1e-9;

  /// Area with the shoelace formula (always positive).
  static double area(List<Offset> points) {
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum.abs() / 2;
  }

  static List<(Offset, Offset)> _edges(List<Offset> points) =>
      [for (var i = 0; i < points.length; i++) (points[i], points[(i + 1) % points.length])];

  static List<Offset> translate(List<Offset> points, Offset delta) => [for (final p in points) p + delta];

  static Rect bounds(List<Offset> points) {
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final p in points) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static double _cross(Offset a, Offset b, Offset c) => (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);

  static bool _onSegment(Offset a, Offset b, Offset p) =>
      _cross(a, b, p).abs() < _eps &&
      p.dx >= math.min(a.dx, b.dx) - _eps && p.dx <= math.max(a.dx, b.dx) + _eps &&
      p.dy >= math.min(a.dy, b.dy) - _eps && p.dy <= math.max(a.dy, b.dy) + _eps;

  /// The segments cross each other (touching is NOT crossing).
  static bool _segmentsCross(Offset a, Offset b, Offset c, Offset d) {
    final d1 = _cross(c, d, a), d2 = _cross(c, d, b), d3 = _cross(a, b, c), d4 = _cross(a, b, d);
    return ((d1 > _eps && d2 < -_eps) || (d1 < -_eps && d2 > _eps)) &&
        ((d3 > _eps && d4 < -_eps) || (d3 < -_eps && d4 > _eps));
  }

  static bool _segmentsTouch(Offset a, Offset b, Offset c, Offset d) =>
      _segmentsCross(a, b, c, d) || _onSegment(c, d, a) || _onSegment(c, d, b) || _onSegment(a, b, c) || _onSegment(a, b, d);

  /// Point inside or on the border.
  static bool contains(List<Offset> points, Offset p) {
    if (_edges(points).any((e) => _onSegment(e.$1, e.$2, p))) return true;

    var inside = false;
    for (final (a, b) in _edges(points)) {
      if ((a.dy > p.dy) != (b.dy > p.dy) && p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool _containsStrictly(List<Offset> points, Offset p) =>
      contains(points, p) && !_edges(points).any((e) => _onSegment(e.$1, e.$2, p));

  /// Simple polygon : at least 3 points, a real area, no edge crossing another one.
  static bool isSimple(List<Offset> points) {
    final n = points.length;
    if (n < 3 || area(points) < _eps) return false;

    final list = _edges(points);
    if (list.any((e) => (e.$2 - e.$1).distance < _eps)) return false;

    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final (a, b) = list[i];
        final (c, d) = list[j];
        if (j == i + 1) {
          if (_onSegment(a, b, d) || _onSegment(c, d, a)) return false;
        } else if (i == 0 && j == n - 1) {
          if (_onSegment(c, d, b) || _onSegment(a, b, c)) return false;
        } else if (_segmentsTouch(a, b, c, d)) {
          return false;
        }
      }
    }
    return true;
  }

  /// A point strictly inside the polygon.
  static Offset interiorPoint(List<Offset> points) {
    for (final (a, b) in _edges(points)) {
      final length = (b - a).distance;
      if (length < _eps) continue;
      final mid = (a + b) / 2;
      final normal = Offset(-(b.dy - a.dy) / length, (b.dx - a.dx) / length);
      for (final side in [1.0, -1.0]) {
        final candidate = mid + normal * (side * 1e-4);
        if (contains(points, candidate)) return candidate;
      }
    }
    return points.first;
  }

  /// [inner] is entirely inside [outer] (sharing borders is allowed).
  static bool isInside(List<Offset> inner, List<Offset> outer) =>
      inner.every((p) => contains(outer, p)) &&
      !_edges(inner).any((e) => _edges(outer).any((f) => _segmentsCross(e.$1, e.$2, f.$1, f.$2))) &&
      _edges(inner).every((e) => contains(outer, (e.$1 + e.$2) / 2));

  /// The polygons share some area (only touching borders is NOT overlapping).
  static bool overlap(List<Offset> p1, List<Offset> p2) =>
      _edges(p1).any((e) => _edges(p2).any((f) => _segmentsCross(e.$1, e.$2, f.$1, f.$2))) ||
      _containsStrictly(p2, interiorPoint(p1)) ||
      _containsStrictly(p1, interiorPoint(p2));

  /// Where to write the name of a shape : its centroid, or a point inside for odd shapes (L, U...).
  static Offset labelPoint(List<Offset> points) {
    final a = area(points);
    if (a < _eps) return points.first;

    var cx = 0.0, cy = 0.0, signed = 0.0;
    for (final (p, q) in _edges(points)) {
      final f = p.dx * q.dy - q.dx * p.dy;
      signed += f;
      cx += (p.dx + q.dx) * f;
      cy += (p.dy + q.dy) * f;
    }
    final centroid = Offset(cx / (3 * signed), cy / (3 * signed));
    return contains(points, centroid) ? centroid : interiorPoint(points);
  }

  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final lengthSquared = (b - a).distanceSquared;
    if (lengthSquared < _eps) return (p - a).distance;
    final t = (((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / lengthSquared).clamp(0.0, 1.0);
    return (p - Offset(a.dx + t * (b.dx - a.dx), a.dy + t * (b.dy - a.dy))).distance;
  }
}
