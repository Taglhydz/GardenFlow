/**
 * Suggestion engine : ranks the plants of the catalog for a parcel and a month.
 *
 * Pure functions (no database access) so the rules are easy to test and to tune.
 * Every score change comes with a reason { code, impact, params } that the app translates
 * (suggestion_reasons.<code> in the translation files).
 */

// ==========
// Parameters
// ==========
const BASE_SCORE = 50;

const WEIGHTS = {
  inSeason         : 15,  // can go in the ground this month
  soilMatch        : 10,
  soilMismatch     : -5,
  sunMatch         : 10,
  sunEnough        : 5,   // more sun than needed
  sunTooLow        : [-10, -25], // 1 or 2 levels below the need
  waterMatch       : 5,
  tooDry           : [-5, -15],
  tooWet           : -10, // 2 levels above the need
  goodCompanion    : 12,
  badCompanion     : -20,
  goodNeighbour    : 6,   // association with a crop of an adjacent parcel
  badNeighbour     : -10,
  alreadyInParcel  : -5,
  rotation         : [-25, -15, -8], // same family harvested < 1, < 2, < 3 years ago
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

/** Two rectangles are neighbours when the gap between them is at most `distance` on both axes (overlap included). */
const areNeighbours = (a, b, distance = NEIGHBOUR_DISTANCE_M) => {
  const gapX = Math.max(a.pos_x, b.pos_x) - Math.min(a.pos_x + a.width, b.pos_x + b.width);
  const gapY = Math.max(a.pos_y, b.pos_y) - Math.min(a.pos_y + a.length, b.pos_y + b.length);
  return gapX <= distance && gapY <= distance;
};

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

/**
 * Associations with the crops still in the ground, in the parcel and in the neighbour parcels.
 * Each other plant counts once, the parcel wins over the neighbours.
 */
const scoreAssociations = (plant, context, add) => {
  const { parcelPlantIds, neighbourPlantIds, associationIndex, plantsById } = context;

  if (parcelPlantIds.has(plant.id)) {
    add(WEIGHTS.alreadyInParcel, 'already_in_parcel', 'info');
  }

  for (const [otherIds, isNeighbour] of [[parcelPlantIds, false], [neighbourPlantIds, true]]) {
    for (const otherId of otherIds) {
      if (otherId === plant.id || (isNeighbour && parcelPlantIds.has(otherId))) continue;

      const relation = relationBetween(associationIndex, plant.id, otherId);
      if (!relation) continue;

      const params = { plant_code: plantsById.get(otherId)?.code };
      if (relation === 'positive') {
        add(isNeighbour ? WEIGHTS.goodNeighbour : WEIGHTS.goodCompanion,
          isNeighbour ? 'good_neighbour' : 'good_companion', 'positive', params);
      } else {
        add(isNeighbour ? WEIGHTS.badNeighbour : WEIGHTS.badCompanion,
          isNeighbour ? 'bad_neighbour' : 'bad_companion', 'negative', params);
      }
    }
  }
};

/** Crop rotation : penalty when the same family was harvested in this parcel recently (most recent only). */
const scoreRotation = (plant, context, add) => {
  if (!plant.family) return;

  const { harvestedCrops, plantsById, today } = context;
  let mostRecent = null;

  for (const crop of harvestedCrops) {
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

// ======
// Engine
// ======

/**
 * @param {object}   input
 * @param {object}   input.parcel        the parcel to plant (pos_x, pos_y, width, length, soil_type, sunlight, moisture)
 * @param {object[]} input.parcels       all the parcels of the garden (to find the neighbours)
 * @param {object[]} input.crops         all the crops of the garden
 * @param {object[]} input.plants        catalog, with `periods`
 * @param {object[]} input.associations  plant associations
 * @param {number}   input.month         1-12
 * @param {string}   input.today         'YYYY-MM-DD'
 * @returns {object[]} suggestions sorted by score : { plant_id, plant_code, score, actions, reasons }
 */
const suggestPlants = ({ parcel, parcels, crops, plants, associations, month, today }) => {
  const plantsById = new Map(plants.map((p) => [p.id, p]));
  const neighbourIds = new Set(
    parcels.filter((p) => p.id !== parcel.id && areNeighbours(parcel, p)).map((p) => p.id)
  );

  // crops still in the ground (planned ones included) vs harvested crops
  const inGround = crops.filter((c) => !c.actual_harvest_date);

  const context = {
    plantsById,
    today,
    associationIndex : buildAssociationIndex(associations),
    parcelPlantIds   : new Set(inGround.filter((c) => c.parcel_id === parcel.id).map((c) => c.plant_id)),
    neighbourPlantIds: new Set(inGround.filter((c) => neighbourIds.has(c.parcel_id)).map((c) => c.plant_id)),
    harvestedCrops   : crops.filter((c) => c.parcel_id === parcel.id && c.actual_harvest_date),
  };

  const suggestions = [];

  for (const plant of plants) {
    const now = periodsNow(plant, month);
    // what can be done this month : put it in the parcel, or sow it under cover to plant it later
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
