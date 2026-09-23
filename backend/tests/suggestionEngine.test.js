/**
 * Unit tests of the suggestion engine (no database).
 */
const {
  suggestPlants, areNeighbours, isMonthInRange, monthsBetween, WEIGHTS, BASE_SCORE,
} = require('../src/services/suggestionEngine');

// ---- test data ----
const plant = (id, code, extra = {}) => ({
  id,
  code,
  family        : null,
  sunlight_need : 'medium',
  water_need    : 'medium',
  preferred_soil: 'standard',
  periods       : [{ type: 'sow_outdoor', start_month: 1, end_month: 12 }],
  ...extra,
});

const parcel = (id, extra = {}) => ({
  id,
  pos_x    : 0,
  pos_y    : 0,
  width    : 1,
  length   : 1,
  soil_type: 'standard',
  sunlight : 'medium',
  moisture : 'medium',
  ...extra,
});

const crop = (parcelId, plantId, extra = {}) => ({ parcel_id: parcelId, plant_id: plantId, actual_harvest_date: null, ...extra });

const run = (overrides = {}) => suggestPlants({
  parcel      : parcel(1),
  parcels     : [parcel(1)],
  crops       : [],
  plants      : [plant(10, 'tomato')],
  associations: [],
  month       : 5,
  today       : '2026-05-15',
  ...overrides,
});

const find = (suggestions, code) => suggestions.find((s) => s.plant_code === code);
const codes = (suggestion) => suggestion.reasons.map((r) => r.code);

// ---- helpers ----
describe('helpers', () => {
  test('isMonthInRange handles ranges wrapping around the year', () => {
    expect(isMonthInRange(4, 3, 5)).toBe(true);
    expect(isMonthInRange(6, 3, 5)).toBe(false);
    expect(isMonthInRange(11, 10, 3)).toBe(true);
    expect(isMonthInRange(2, 10, 3)).toBe(true);
    expect(isMonthInRange(6, 10, 3)).toBe(false);
  });

  test('areNeighbours : touching, close, overlapping, far', () => {
    const a = parcel(1, { pos_x: 0, pos_y: 0, width: 2, length: 2 });
    expect(areNeighbours(a, parcel(2, { pos_x: 2, pos_y: 0 }))).toBe(true);    // touching
    expect(areNeighbours(a, parcel(2, { pos_x: 2.4, pos_y: 1 }))).toBe(true);  // 40 cm gap
    expect(areNeighbours(a, parcel(2, { pos_x: 1, pos_y: 1 }))).toBe(true);    // overlapping
    expect(areNeighbours(a, parcel(2, { pos_x: 3, pos_y: 0 }))).toBe(false);   // 1 m gap
    expect(areNeighbours(a, parcel(2, { pos_x: 2.3, pos_y: 2.3 }))).toBe(true); // diagonal corner, 30 cm
  });

  test('monthsBetween', () => {
    expect(monthsBetween('2025-07-10', '2026-05-15')).toBe(10);
    expect(monthsBetween('2024-05-01', '2026-05-15')).toBe(24);
  });
});

// ---- season ----
describe('season', () => {
  test('only plants that can be sown or planted this month are suggested', () => {
    const result = run({
      plants: [
        plant(10, 'tomato', { periods: [{ type: 'plant_out', start_month: 5, end_month: 6 }] }),
        plant(11, 'garlic', { periods: [{ type: 'plant_out', start_month: 10, end_month: 3 }] }),
      ],
    });
    expect(result.map((s) => s.plant_code)).toEqual(['tomato']);
    expect(find(result, 'tomato').actions).toEqual(['plant_out']);
  });

  test('a plant with several sowing periods is suggested in each of them', () => {
    const spinach = plant(10, 'spinach', { periods: [
      { type: 'sow_outdoor', start_month: 2, end_month: 4 },
      { type: 'sow_outdoor', start_month: 8, end_month: 10 },
    ] });
    expect(run({ plants: [spinach], month: 3 })).toHaveLength(1);
    expect(run({ plants: [spinach], month: 9 })).toHaveLength(1);
    expect(run({ plants: [spinach], month: 6 })).toHaveLength(0);
  });

  test('a plant to sow under cover only is suggested lower, with an info reason', () => {
    const result = run({
      plants: [
        plant(10, 'tomato', { periods: [{ type: 'sow_indoor', start_month: 3, end_month: 4 }] }),
        plant(11, 'carrot', { periods: [{ type: 'sow_outdoor', start_month: 3, end_month: 7 }] }),
      ],
      month: 4,
    });
    expect(result.map((s) => s.plant_code)).toEqual(['carrot', 'tomato']);
    expect(find(result, 'tomato').actions).toEqual(['sow_indoor']);
    expect(codes(find(result, 'tomato'))).toContain('sow_indoor_now');
    expect(find(result, 'carrot').score - find(result, 'tomato').score).toBe(WEIGHTS.inSeason);
  });
});

// ---- growing conditions ----
describe('growing conditions', () => {
  test('matching soil, sun and water give the best score', () => {
    const tomato = plant(10, 'tomato', { preferred_soil: 'humus', sunlight_need: 'high', water_need: 'medium' });
    const good = run({ plants: [tomato], parcel: parcel(1, { soil_type: 'humus', sunlight: 'high', moisture: 'medium' }) })[0];

    expect(good.score).toBe(BASE_SCORE + WEIGHTS.inSeason + WEIGHTS.soilMatch + WEIGHTS.sunMatch + WEIGHTS.waterMatch);
    expect(codes(good)).toEqual(expect.arrayContaining(['soil_match', 'sun_match', 'water_match']));
  });

  test('not enough sun is penalized, more when the gap is bigger', () => {
    const tomato = plant(10, 'tomato', { sunlight_need: 'high' });
    const medium = run({ plants: [tomato], parcel: parcel(1, { sunlight: 'medium' }) })[0];
    const low    = run({ plants: [tomato], parcel: parcel(1, { sunlight: 'low' }) })[0];

    expect(codes(medium)).toContain('sun_too_low');
    expect(low.score).toBeLessThan(medium.score);
  });

  test('a standard soil suits everything (no soil reason)', () => {
    const result = run({ plants: [plant(10, 'tomato', { preferred_soil: 'humus' })] })[0];
    expect(codes(result)).not.toContain('soil_match');
    expect(codes(result)).not.toContain('soil_mismatch');
  });

  test('wrong soil, too dry and too wet are negative reasons', () => {
    const thyme = plant(10, 'thyme', { preferred_soil: 'chalky', water_need: 'low' });
    const result = run({ plants: [thyme], parcel: parcel(1, { soil_type: 'clay', moisture: 'high' }) })[0];
    expect(codes(result)).toEqual(expect.arrayContaining(['soil_mismatch', 'too_wet']));

    const celery = plant(11, 'celery', { water_need: 'high' });
    expect(codes(run({ plants: [celery], parcel: parcel(1, { moisture: 'low' }) })[0])).toContain('too_dry');
  });
});

// ---- associations ----
describe('associations', () => {
  const plants = [plant(10, 'tomato'), plant(20, 'basil'), plant(30, 'potato')];
  const associations = [
    { plant_id_1: 10, plant_id_2: 20, relation_type: 'positive' },
    { plant_id_1: 10, plant_id_2: 30, relation_type: 'negative' },
  ];

  test('good and bad companions in the parcel', () => {
    const result = run({ plants, associations, crops: [crop(1, 10)] });

    expect(codes(find(result, 'basil'))).toContain('good_companion');
    expect(find(result, 'basil').reasons.find((r) => r.code === 'good_companion').params).toEqual({ plant_code: 'tomato' });
    expect(codes(find(result, 'potato'))).toContain('bad_companion');
    expect(result[0].plant_code).toBe('basil');
    expect(result.at(-1).plant_code).toBe('potato');
  });

  test('associations are symmetric', () => {
    // basil is in the parcel : tomato (plant_id_1 of the pair) gets the bonus too
    const result = run({ plants, associations, crops: [crop(1, 20)] });
    expect(codes(find(result, 'tomato'))).toContain('good_companion');
  });

  test('neighbour parcels count less than the parcel itself', () => {
    const parcels = [parcel(1), parcel(2, { pos_x: 1 }), parcel(3, { pos_x: 5 })];

    const inParcel  = find(run({ plants, associations, parcels, crops: [crop(1, 10)] }), 'basil');
    const neighbour = find(run({ plants, associations, parcels, crops: [crop(2, 10)] }), 'basil');
    const far       = find(run({ plants, associations, parcels, crops: [crop(3, 10)] }), 'basil');

    expect(codes(neighbour)).toContain('good_neighbour');
    expect(codes(far)).not.toContain('good_neighbour');
    expect(inParcel.score).toBeGreaterThan(neighbour.score);
    expect(neighbour.score).toBeGreaterThan(far.score);
  });

  test('a plant in both the parcel and a neighbour parcel counts once, as in the parcel', () => {
    const parcels = [parcel(1), parcel(2, { pos_x: 1 })];
    const basil = find(run({ plants, associations, parcels, crops: [crop(1, 10), crop(2, 10)] }), 'basil');
    expect(codes(basil).filter((c) => c.includes('companion') || c.includes('neighbour'))).toEqual(['good_companion']);
  });

  test('harvested crops are no longer companions', () => {
    const result = run({ plants, associations, crops: [crop(1, 10, { actual_harvest_date: '2026-04-01' })] });
    expect(codes(find(result, 'basil'))).not.toContain('good_companion');
  });

  test('a plant already in the parcel is slightly penalized', () => {
    const result = run({ plants, associations, crops: [crop(1, 10)] });
    expect(codes(find(result, 'tomato'))).toContain('already_in_parcel');
  });
});

// ---- rotation ----
describe('crop rotation', () => {
  const plants = [
    plant(10, 'tomato', { family: 'solanaceae' }),
    plant(30, 'potato', { family: 'solanaceae' }),
    plant(40, 'carrot', { family: 'apiaceae' }),
  ];

  test('same family harvested recently in the parcel is penalized, less and less with time', () => {
    const score = (harvest) => find(run({ plants, crops: [crop(1, 30, { actual_harvest_date: harvest })] }), 'tomato');

    const lastYear  = score('2025-08-01'); // 9 months ago
    const twoYears  = score('2024-08-01'); // 21 months
    const fourYears = score('2022-08-01'); // too old

    expect(codes(lastYear)).toContain('rotation_same_family');
    expect(lastYear.reasons.find((r) => r.code === 'rotation_same_family').params).toMatchObject({ family: 'solanaceae', plant_code: 'potato', months_ago: 9 });
    expect(lastYear.score).toBeLessThan(twoYears.score);
    expect(codes(fourYears)).not.toContain('rotation_same_family');
  });

  test('another family or another parcel is not concerned', () => {
    const result = run({
      plants,
      parcels: [parcel(1), parcel(2, { pos_x: 1 })],
      crops  : [crop(1, 40, { actual_harvest_date: '2025-08-01' }), crop(2, 30, { actual_harvest_date: '2025-08-01' })],
    });
    expect(codes(find(result, 'tomato'))).not.toContain('rotation_same_family');
  });
});

test('scores stay between 0 and 100', () => {
  const plants = [plant(10, 'tomato', { family: 'solanaceae', sunlight_need: 'high', water_need: 'high', preferred_soil: 'humus' })];
  const others = Array.from({ length: 10 }, (_, i) => plant(100 + i, `bad_${i}`, { periods: [] }));
  const associations = others.map((o) => ({ plant_id_1: 10, plant_id_2: o.id, relation_type: 'negative' }));

  const [result] = run({
    plants      : [...plants, ...others],
    associations,
    parcel      : parcel(1, { sunlight: 'low', moisture: 'low', soil_type: 'clay' }),
    crops       : others.map((o) => crop(1, o.id)),
  });
  expect(result.score).toBe(0);
});
