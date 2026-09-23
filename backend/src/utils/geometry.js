/**
 * Polygon geometry (meters). A polygon is an array of { x, y } points, not closed
 * (the last point is implicitly linked to the first one).
 */

const EPSILON = 1e-9;

/** Area with the shoelace formula (always positive). */
const polygonArea = (points) => {
  let sum = 0;
  for (let i = 0; i < points.length; i++) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return Math.abs(sum) / 2;
};

const edges = (points) => points.map((p, i) => [p, points[(i + 1) % points.length]]);

const translate = (points, dx, dy) => points.map((p) => ({ x: p.x + dx, y: p.y + dy }));

/** > 0 : c is on the left of a -> b, < 0 : on the right, 0 : aligned */
const cross = (a, b, c) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);

const onSegment = (a, b, p) =>
  Math.abs(cross(a, b, p)) < EPSILON &&
  p.x >= Math.min(a.x, b.x) - EPSILON && p.x <= Math.max(a.x, b.x) + EPSILON &&
  p.y >= Math.min(a.y, b.y) - EPSILON && p.y <= Math.max(a.y, b.y) + EPSILON;

/** The two segments cross each other (touching at an end or along an edge is NOT crossing). */
const segmentsCross = (a, b, c, d) => {
  const d1 = cross(c, d, a);
  const d2 = cross(c, d, b);
  const d3 = cross(a, b, c);
  const d4 = cross(a, b, d);
  return ((d1 > EPSILON && d2 < -EPSILON) || (d1 < -EPSILON && d2 > EPSILON)) &&
         ((d3 > EPSILON && d4 < -EPSILON) || (d3 < -EPSILON && d4 > EPSILON));
};

/** The two segments have at least one common point (touching included). */
const segmentsTouch = (a, b, c, d) =>
  segmentsCross(a, b, c, d) || onSegment(c, d, a) || onSegment(c, d, b) || onSegment(a, b, c) || onSegment(a, b, d);

/** Point strictly inside or on the border. */
const containsPoint = (points, p) => {
  if (edges(points).some(([a, b]) => onSegment(a, b, p))) return true;

  // ray casting
  let inside = false;
  for (const [a, b] of edges(points)) {
    if ((a.y > p.y) !== (b.y > p.y) && p.x < ((b.x - a.x) * (p.y - a.y)) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
};

/** Simple polygon : at least 3 points, a real area, no edge crossing another one. */
const isSimplePolygon = (points) => {
  const n = points.length;
  if (n < 3 || polygonArea(points) < EPSILON) return false;

  const list = edges(points);
  if (list.some(([a, b]) => Math.hypot(b.x - a.x, b.y - a.y) < EPSILON)) return false; // duplicated point

  for (let i = 0; i < n; i++) {
    for (let j = i + 1; j < n; j++) {
      const [a, b] = list[i];
      const [c, d] = list[j];
      if (j === i + 1) {
        // consecutive edges a-b, b-d : only b in common, no going back on the same line
        if (onSegment(a, b, d) || onSegment(c, d, a)) return false;
      } else if (i === 0 && j === n - 1) {
        // last edge c-a and first edge a-b : only a in common
        if (onSegment(c, d, b) || onSegment(a, b, c)) return false;
      } else if (segmentsTouch(a, b, c, d)) {
        return false;
      }
    }
  }
  return true;
};

/** Centroid-like point strictly inside the polygon, used by the overlap test. */
const interiorPoint = (points) => {
  // middle of the first edge, pushed a little towards the inside
  for (const [a, b] of edges(points)) {
    const mid = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
    const len = Math.hypot(b.x - a.x, b.y - a.y);
    if (len < EPSILON) continue;
    const normal = { x: -(b.y - a.y) / len, y: (b.x - a.x) / len };
    for (const side of [1, -1]) {
      const candidate = { x: mid.x + side * normal.x * 1e-4, y: mid.y + side * normal.y * 1e-4 };
      if (containsPoint(points, candidate)) return candidate;
    }
  }
  return points[0];
};

/** `inner` is entirely inside `outer` (sharing borders is allowed). */
const isInside = (inner, outer) =>
  inner.every((p) => containsPoint(outer, p)) &&
  !edges(inner).some(([a, b]) => edges(outer).some(([c, d]) => segmentsCross(a, b, c, d))) &&
  // concave outer polygon : the middle of each inner edge must be inside too
  edges(inner).every(([a, b]) => containsPoint(outer, { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }));

/** The polygons share some area (only touching borders is NOT overlapping). */
const overlap = (p1, p2) =>
  edges(p1).some(([a, b]) => edges(p2).some(([c, d]) => segmentsCross(a, b, c, d))) ||
  containsStrictly(p2, interiorPoint(p1)) ||
  containsStrictly(p1, interiorPoint(p2));

const containsStrictly = (points, p) => containsPoint(points, p) && !edges(points).some(([a, b]) => onSegment(a, b, p));

const pointSegmentDistance = (p, a, b) => {
  const lengthSquared = (b.x - a.x) ** 2 + (b.y - a.y) ** 2;
  if (lengthSquared < EPSILON) return Math.hypot(p.x - a.x, p.y - a.y);
  const t = Math.max(0, Math.min(1, ((p.x - a.x) * (b.x - a.x) + (p.y - a.y) * (b.y - a.y)) / lengthSquared));
  return Math.hypot(p.x - (a.x + t * (b.x - a.x)), p.y - (a.y + t * (b.y - a.y)));
};

/** Shortest distance between the borders of two polygons, 0 when they touch or overlap. */
const polygonDistance = (p1, p2) => {
  if (overlap(p1, p2)) return 0;

  let min = Infinity;
  for (const [a, b] of edges(p1)) {
    for (const [c, d] of edges(p2)) {
      if (segmentsTouch(a, b, c, d)) return 0;
      min = Math.min(min, pointSegmentDistance(a, c, d), pointSegmentDistance(b, c, d),
        pointSegmentDistance(c, a, b), pointSegmentDistance(d, a, b));
    }
  }
  return min;
};

module.exports = {
  polygonArea,
  translate,
  containsPoint,
  isSimplePolygon,
  isInside,
  overlap,
  polygonDistance,
};
