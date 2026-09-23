/**
 * Suggestion engine : ranks the plants of the catalog for a parcel (or a zone of a parcel) and a month.
 *
 * Pure functions (no database access) so the rules are easy to test and to tune.
 * Every score change comes with a reason { code, impact, params } that the app translates
 * (suggestion_reasons.<code> in the translation files).
 */
const { translate, polygonDistance } = require('../utils/geometry');

// ==========
// Parameters
// ==========
const BASE_SCORE = 50;

const WEIGHTS = {
  inSeason       : 15,  // can go in the ground this month
  soilMatch      : 10,
  soilMismatch   : -5,
  sunMatch       : 10,
  sunEnough      : 5,   // more sun than needed
  sunTooLow      : [-10, -25], // 1 or 2 levels below the need
  waterMatch     : 5,
  tooDry         : [-5, -15],
  tooWet         : -10, // 2 levels above the need
  // associations, from the closest crops to the farthest
  goodCompanion  : 12,  // same zone (or same parcel when there is no zone)
  badCompanion   : -20,
  goodInParcel   : 8,   // another place of the same parcel
  badInParcel    : -14,
  goodNeighbour  : 6,   // an adjacent parcel
  badNeighbour   : -10,
  alreadyHere    : -5,
  rotation       : [-25, -15, -8], // same family harvested here < 1, < 2, < 3 years ago
  tooSmall       : -30, // not even one plant fits (spacing)
};

/** Parcels closer than this (meters) are neighbours. */
const NEIGHBOUR_DISTANCE_M = 0.5;

const LEVEL = { low: 0, medium: 1, high: 2 };

// =======
// Helpers
// =======

/** Month ranges may wrap around the year (10 -> 3 = October to March). */
const isMonthInRange = (month, start, end) =>
  start <= end ? month >= start && month <= end : month >= start || month <= end;

const periodsNow = (plant, month) => new Set(
  (plant.periods || []).filter((p) => isMonthInRange(month, p.start_month, p.end_month)).map((p) => p.type)
);

/** Shape of a parcel on the garden plan (its shape is relative to its position). */
const absoluteShape = (parcel) => translate(parcel.shape, parcel.pos_x, parcel.pos_y);

/** Two parcels are neighbours when the gap between their borders is at most `distance`. */
const areNeighbours = (a, b, distance = NEIGHBOUR_DISTANCE_M) =>
  polygonDistance(absoluteShape(a), absoluteShape(b)) <= distance;

/** Full months between two 'YYYY-MM-DD' dates (or Date objects). */
const monthsBetween = (from, to) => {
  const a = new Date(from);
  const b = new Date(to);
  return (b.getFullYear() - a.getFullYear()) * 12 + (b.getMonth() - a.getMonth());
};

/** Symmetric association lookup : "<id1>-<id2>" with id1 < id2 -> relation_type */
const buildAssociationIndex = (associations) => new Map(
  associations.map((a) => [`${Math.min(a.plant_id_1, a.plant_id_2)}-${Math.max(a.plant_id_1, a.plant_id_2)}`, a.relation_type])
);

const relationBetween = (index, plantA, plantB) =>
  index.get(`${Math.min(plantA, plantB)}-${Math.max(plantA, plantB)}`);

// ===========
// Score rules
// ===========

const scoreSoil = (plant, parcel, add) => {
  // 'standard' soil suits everything and plants that prefer 'standard' grow anywhere
  if (plant.preferred_soil === 'standard' || parcel.soil_type === 'standard') return;

  if (plant.preferred_soil === parcel.soil_type) {
    add(WEIGHTS.soilMatch, 'soil_match', 'positive');
  } else {
    add(WEIGHTS.soilMismatch, 'soil_mismatch', 'negative', { preferred_soil: plant.preferred_soil });
  }
};

const scoreSunlight = (plant, parcel, add) => {
  const diff = LEVEL[parcel.sunlight] - LEVEL[plant.sunlight_need];

  if (diff === 0) add(WEIGHTS.sunMatch, 'sun_match', 'positive');
  else if (diff > 0) add(WEIGHTS.sunEnough, 'sun_match', 'positive');
  else add(WEIGHTS.sunTooLow[-diff - 1], 'sun_too_low', 'negative', { need: plant.sunlight_need });
};

const scoreWater = (plant, parcel, add) => {
  const diff = LEVEL[parcel.moisture] - LEVEL[plant.water_need];

  if (diff === 0) add(WEIGHTS.waterMatch, 'water_match', 'positive');
  else if (diff < 0) add(WEIGHTS.tooDry[-diff - 1], 'too_dry', 'negative', { need: plant.water_need });
  else if (diff === 2) add(WEIGHTS.tooWet, 'too_wet', 'negative', { need: plant.water_need });
};

/** From the closest crops to the farthest : each other plant counts once, in its closest tier. */
const ASSOCIATION_TIERS = [
  { key: 'here',      good: [WEIGHTS.goodCompanion, 'good_companion'], bad: [WEIGHTS.badCompanion, 'bad_companion'] },
  { key: 'inParcel',  good: [WEIGHTS.goodInParcel, 'good_in_parcel'],  bad: [WEIGHTS.badInParcel, 'bad_in_parcel'] },
  { key: 'neighbour', good: [WEIGHTS.goodNeighbour, 'good_neighbour'], bad: [WEIGHTS.badNeighbour, 'bad_neighbour'] },
];

const scoreAssociations = (plant, context, add) => {
  const { plantIds, associationIndex, plantsById } = context;

  if (plantIds.here.has(plant.id)) {
    add(WEIGHTS.alreadyHere, 'already_here', 'info');
  }

  const counted = new Set([plant.id]);
  for (const tier of ASSOCIATION_TIERS) {
    for (const otherId of plantIds[tier.key]) {
      if (counted.has(otherId)) continue;
      counted.add(otherId);

      const relation = relationBetween(associationIndex, plant.id, otherId);
      if (!relation) continue;

      const [points, code] = relation === 'positive' ? tier.good : tier.bad;
      add(points, code, relation === 'positive' ? 'positive' : 'negative', { plant_code: plantsById.get(otherId)?.code });
    }
  }
};

/** Crop rotation : penalty when the same family was harvested here recently (most recent only). */
const scoreRotation = (plant, context, add) => {
  if (!plant.family) return;

  const { harvestedHere, plantsById, today } = context;
  let mostRecent = null;

  for (const crop of harvestedHere) {
    const other = plantsById.get(crop.plant_id);
    if (other?.family !== plant.family) continue;

    const monthsAgo = Math.max(0, monthsBetween(crop.actual_harvest_date, today));
    if (monthsAgo < 36 && (!mostRecent || monthsAgo < mostRecent.monthsAgo)) {
      mostRecent = { monthsAgo, plantCode: other.code };
    }
  }

  if (mostRecent) {
    add(WEIGHTS.rotation[Math.floor(mostRecent.monthsAgo / 12)], 'rotation_same_family', 'negative', {
      family    : plant.family,
      plant_code: mostRecent.plantCode,
      months_ago: mostRecent.monthsAgo,
    });
  }
};

/** How many plants fit in the area, with the spacing of the plant (square grid). */
const scoreCapacity = (plant, area, add) => {
  if (!area || !plant.spacing_cm) return;

  const spacing = plant.spacing_cm / 100;
  const count = Math.floor(area / (spacing * spacing));

  if (count < 1) add(WEIGHTS.tooSmall, 'too_small', 'negative', { spacing_cm: plant.spacing_cm });
  else add(0, 'capacity', 'info', { count });
};

// ======
// Engine
// ======

/**
 * @param {object}   input
 * @param {object}   input.parcel        the parcel (pos_x, pos_y, shape, area_m2, soil_type, sunlight, moisture)
 * @param {object}   [input.zone]        a zone of this parcel (shape, area_m2) : suggestions for this zone only
 * @param {object[]} input.parcels       all the parcels of the garden (to find the neighbours)
 * @param {object[]} input.crops         all the crops of the garden (with parcel_id and zone_id)
 * @param {object[]} input.plants        catalog, with `periods`
 * @param {object[]} input.associations  plant associations
 * @param {number}   input.month         1-12
 * @param {string}   input.today         'YYYY-MM-DD'
 * @returns {object[]} suggestions sorted by score : { plant_id, plant_code, score, actions, reasons }
 */
const suggestPlants = ({ parcel, zone = null, parcels, crops, plants, associations, month, today }) => {
  const plantsById = new Map(plants.map((p) => [p.id, p]));
  const neighbourIds = new Set(
    parcels.filter((p) => p.id !== parcel.id && areNeighbours(parcel, p)).map((p) => p.id)
  );

  const parcelCrops = crops.filter((c) => c.parcel_id === parcel.id);
  // "here" = the zone, or the whole parcel when no zone is given
  const isHere = (crop) => !zone || crop.zone_id === zone.id;

  // crops still in the ground (planned ones included) vs harvested crops
  const inGround = crops.filter((c) => !c.actual_harvest_date);
  const plantIdsOf = (list) => new Set(list.map((c) => c.plant_id));

  const context = {
    plantsById,
    today,
    associationIndex: buildAssociationIndex(associations),
    plantIds: {
      here     : plantIdsOf(inGround.filter((c) => c.parcel_id === parcel.id && isHere(c))),
      inParcel : plantIdsOf(inGround.filter((c) => c.parcel_id === parcel.id && !isHere(c))),
      neighbour: plantIdsOf(inGround.filter((c) => neighbourIds.has(c.parcel_id))),
    },
    // rotation : the history of the zone, plus the crops planted in the whole parcel (without zone)
    harvestedHere: parcelCrops.filter((c) => c.actual_harvest_date && (isHere(c) || c.zone_id == null)),
  };

  const area = zone ? zone.area_m2 : parcel.area_m2;
  const suggestions = [];

  for (const plant of plants) {
    const now = periodsNow(plant, month);
    // what can be done this month : put it in the ground, or sow it under cover to plant it later
    const actions = ['sow_outdoor', 'plant_out', 'sow_indoor'].filter((type) => now.has(type));
    if (actions.length === 0) continue;

    let score = BASE_SCORE;
    const reasons = [];
    const add = (points, code, impact, params = {}) => {
      score += points;
      reasons.push({ code, impact, params });
    };

    if (actions.includes('sow_outdoor') || actions.includes('plant_out')) {
      add(WEIGHTS.inSeason, 'in_season', 'positive');
    } else {
      add(0, 'sow_indoor_now', 'info');
    }

    scoreSoil(plant, parcel, add);
    scoreSunlight(plant, parcel, add);
    scoreWater(plant, parcel, add);
    scoreAssociations(plant, context, add);
    scoreRotation(plant, context, add);
    scoreCapacity(plant, area, add);

    suggestions.push({
      plant_id  : plant.id,
      plant_code: plant.code,
      score     : Math.max(0, Math.min(100, Math.round(score))),
      actions,
      reasons,
    });
  }

  return suggestions.sort((a, b) => b.score - a.score || a.plant_code.localeCompare(b.plant_code));
};

module.exports = {
  suggestPlants,
  areNeighbours,
  isMonthInRange,
  monthsBetween,
  WEIGHTS,
  BASE_SCORE,
  NEIGHBOUR_DISTANCE_M,
};
