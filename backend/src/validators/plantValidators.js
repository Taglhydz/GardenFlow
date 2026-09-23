const { z } = require('zod');
const {
  SOIL_TYPES, LEVELS, PLANT_TYPES, RELATION_TYPES, PERIOD_TYPES, id, requiredText, optionalText, month, nonEmpty,
} = require('./common');

// =====
// Plant
// =====
// start_month > end_month is allowed : the period wraps around the year (10 -> 3)
const periodSchema = z.object({
  type       : z.enum(PERIOD_TYPES),
  start_month: month,
  end_month  : month,
});

const plantFields = {
  // stable identifier used as translation key in the app : lowercase snake_case
  code               : z.string().trim().regex(/^[a-z][a-z0-9_]{1,49}$/, 'Code must be lowercase snake_case (e.g. green_bean)'),
  name               : requiredText(100),
  type               : z.enum(PLANT_TYPES).optional(),
  // botanical family, used for crop rotation (translated in the app : plant_family_<family>)
  family             : z.string().trim().regex(/^[a-z][a-z0-9_]{1,49}$/, 'Family must be lowercase snake_case (e.g. solanaceae)').nullable().optional(),
  description        : optionalText(2000),
  days_to_maturity   : z.coerce.number().int().min(1).max(1000).nullable().optional(),
  sunlight_need      : z.enum(LEVELS).optional(),
  water_need         : z.enum(LEVELS).optional(),
  preferred_soil     : z.enum(SOIL_TYPES).optional(),
  spacing_cm         : z.coerce.number().int().min(1).max(1000).optional(),
  // replaces all the periods of the plant
  periods            : z.array(periodSchema).max(20).optional(),
};

const createPlantSchema = z.object(plantFields);
const updatePlantSchema = nonEmpty(z.object(plantFields).partial());

const listPlantsQuerySchema = z.object({
  type  : z.enum(PLANT_TYPES).optional(),
  search: z.string().trim().max(100).optional(),
});

// =================
// Plant association
// =================
const createAssociationSchema = z.object({
  plant_id_1   : id,
  plant_id_2   : id,
  relation_type: z.enum(RELATION_TYPES),
  comment      : optionalText(2000),
}).refine((a) => a.plant_id_1 !== a.plant_id_2, {
  message: 'A plant cannot be associated with itself',
  path   : ['plant_id_2'],
});

// the pair itself can't be changed : delete the association and create a new one
const updateAssociationSchema = nonEmpty(z.object({
  relation_type: z.enum(RELATION_TYPES).optional(),
  comment      : optionalText(2000),
}));

const listAssociationsQuerySchema = z.object({
  plant_id: id.optional(),
});

module.exports = {
  createPlantSchema,
  updatePlantSchema,
  listPlantsQuerySchema,
  createAssociationSchema,
  updateAssociationSchema,
  listAssociationsQuerySchema,
};
