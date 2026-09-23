const { z } = require('zod');
const {
  SOIL_TYPES, LEVELS, id, requiredText, optionalText, optionalDate, positiveDecimal, month, nonEmpty,
} = require('./common');

// ======
// Garden
// ======
const gardenFields = {
  name       : requiredText(100),
  location   : optionalText(255),
  description: optionalText(2000),
};

const createGardenSchema = z.object(gardenFields);
const updateGardenSchema = nonEmpty(z.object(gardenFields).partial());

// ======
// Parcel
// ======
// garden_id is taken from the URL (POST /gardens/:gardenId/parcels) and can't be changed
const parcelFields = {
  name     : requiredText(100),
  area_m2  : positiveDecimal.nullable().optional(),
  pos_x    : positiveDecimal.optional(),
  pos_y    : positiveDecimal.optional(),
  width    : positiveDecimal.optional(),
  length   : positiveDecimal.optional(),
  soil_type: z.enum(SOIL_TYPES).optional(),
  sunlight : z.enum(LEVELS).optional(),
  moisture : z.enum(LEVELS).optional(),
};

const createParcelSchema = z.object(parcelFields);
const updateParcelSchema = nonEmpty(z.object(parcelFields).partial());

// ====
// Crop
// ====
// parcel_id is taken from the URL (POST /parcels/:parcelId/crops) and can't be changed
const cropFields = {
  plant_id             : id,
  sow_date             : optionalDate,
  expected_harvest_date: optionalDate,
  actual_harvest_date  : optionalDate,
  comment              : optionalText(2000),
};

/** Harvest dates can't be before the sowing date ('YYYY-MM-DD' strings compare chronologically). */
const cropDatesIssues = (crop) => {
  const issues = [];
  if (crop.sow_date && crop.expected_harvest_date && crop.expected_harvest_date < crop.sow_date) {
    issues.push({ field: 'expected_harvest_date', message: 'Must be after sow_date' });
  }
  if (crop.sow_date && crop.actual_harvest_date && crop.actual_harvest_date < crop.sow_date) {
    issues.push({ field: 'actual_harvest_date', message: 'Must be after sow_date' });
  }
  return issues;
};

const createCropSchema = z.object(cropFields);
const updateCropSchema = nonEmpty(z.object(cropFields).partial());

// ===========
// Suggestions
// ===========
// the app sends its own month (the server may be in another timezone)
const suggestionsQuerySchema = z.object({
  month: month.optional(),
});

module.exports = {
  createGardenSchema,
  updateGardenSchema,
  createParcelSchema,
  updateParcelSchema,
  createCropSchema,
  updateCropSchema,
  cropDatesIssues,
  suggestionsQuerySchema,
};
