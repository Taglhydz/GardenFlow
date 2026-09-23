/**
 * Unit tests of the polygon geometry (no database).
 */
const {
  polygonArea, translate, containsPoint, isSimplePolygon, isInside, overlap, polygonDistance,
} = require('../src/utils/geometry');

const rect = (x, y, w, h) => [{ x, y }, { x: x + w, y }, { x: x + w, y: y + h }, { x, y: y + h }];

// L shape : 3 x 3 square without its top-right 2 x 2 corner
const lShape = [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 2 }, { x: 3, y: 2 }, { x: 3, y: 3 }, { x: 0, y: 3 }];

describe('area', () => {
  test('rectangle, triangle, L shape, whatever the direction of the points', () => {
    expect(polygonArea(rect(0, 0, 2, 1.5))).toBeCloseTo(3);
    expect(polygonArea([{ x: 0, y: 0 }, { x: 4, y: 0 }, { x: 0, y: 3 }])).toBeCloseTo(6);
    expect(polygonArea(lShape)).toBeCloseTo(5);
    expect(polygonArea([...rect(0, 0, 2, 1.5)].reverse())).toBeCloseTo(3);
  });
});

describe('simple polygon', () => {
  test('valid shapes', () => {
    expect(isSimplePolygon(rect(0, 0, 1, 1))).toBe(true);
    expect(isSimplePolygon(lShape)).toBe(true);
    expect(isSimplePolygon([{ x: 0, y: 0 }, { x: 2, y: 0 }, { x: 1, y: 1 }])).toBe(true);
  });

  test('invalid shapes', () => {
    // bow tie : edges crossing
    expect(isSimplePolygon([{ x: 0, y: 0 }, { x: 2, y: 2 }, { x: 2, y: 0 }, { x: 0, y: 2 }])).toBe(false);
    // flat : all points aligned
    expect(isSimplePolygon([{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 2, y: 0 }])).toBe(false);
    // duplicated point
    expect(isSimplePolygon([{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 0 }, { x: 0, y: 1 }])).toBe(false);
    // going back on the same line
    expect(isSimplePolygon([{ x: 0, y: 0 }, { x: 2, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 1 }])).toBe(false);
    // too few points
    expect(isSimplePolygon([{ x: 0, y: 0 }, { x: 1, y: 1 }])).toBe(false);
  });
});

describe('contains / inside / overlap', () => {
  test('point in an L shape (concave), border included', () => {
    expect(containsPoint(lShape, { x: 0.5, y: 0.5 })).toBe(true);
    expect(containsPoint(lShape, { x: 2, y: 1 })).toBe(false); // in the missing corner
    expect(containsPoint(lShape, { x: 1, y: 1 })).toBe(true);  // on the border
  });

  test('a zone inside a parcel', () => {
    expect(isInside(rect(0.2, 0.2, 0.5, 0.5), rect(0, 0, 1, 1))).toBe(true);
    expect(isInside(rect(0, 0, 1, 1), rect(0, 0, 1, 1))).toBe(true);        // same shape
    expect(isInside(rect(0.5, 0.5, 1, 1), rect(0, 0, 1, 1))).toBe(false);   // sticks out
    // every point of the rectangle is in the L shape but it crosses the missing corner
    expect(isInside(rect(0, 1.5, 3, 1.5), lShape)).toBe(false);
    expect(isInside(rect(0, 2, 3, 1), lShape)).toBe(true);
    expect(isInside(rect(0.5, 0.5, 2, 2), lShape)).toBe(false);
  });

  test('overlap, touching is not overlapping', () => {
    expect(overlap(rect(0, 0, 2, 2), rect(1, 1, 2, 2))).toBe(true);
    expect(overlap(rect(0, 0, 3, 3), rect(1, 1, 1, 1))).toBe(true);   // one inside the other
    expect(overlap(rect(1, 1, 1, 1), rect(0, 0, 3, 3))).toBe(true);
    expect(overlap(rect(0, 0, 1, 1), rect(1, 0, 1, 1))).toBe(false);  // shared border
    expect(overlap(rect(0, 0, 1, 1), rect(3, 3, 1, 1))).toBe(false);
    expect(overlap(rect(0, 0, 1, 1), rect(0, 0, 1, 1))).toBe(true);   // same shape
  });
});

describe('distance', () => {
  test('between borders, 0 when touching or overlapping', () => {
    expect(polygonDistance(rect(0, 0, 1, 1), rect(1.4, 0, 1, 1))).toBeCloseTo(0.4);
    expect(polygonDistance(rect(0, 0, 1, 1), rect(1, 0, 1, 1))).toBe(0);
    expect(polygonDistance(rect(0, 0, 2, 2), rect(1, 1, 2, 2))).toBe(0);
    expect(polygonDistance(rect(0, 0, 1, 1), rect(4, 5, 1, 1))).toBeCloseTo(5); // corner to corner : 3-4-5
  });
});

test('translate', () => {
  expect(translate(rect(0, 0, 1, 1), 2, 3)[2]).toEqual({ x: 3, y: 4 });
});
