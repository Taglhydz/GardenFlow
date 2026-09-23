const { z } = require('zod');
const { isSimplePolygon, polygonArea } = require('../utils/geometry');

// Must stay in sync with the ENUMs of schema.sql
const SOIL_TYPES     = ['standard', 'clay', 'sandy', 'loamy', 'humus', 'chalky'];
const LEVELS         = ['low', 'medium', 'high'];
const PLANT_TYPES    = ['vegetable', 'fruit', 'herb', 'flower'];
const RELATION_TYPES = ['positive', 'negative'];
const ROLES          = ['user', 'admin'];
const PERIOD_TYPES   = ['sow_indoor', 'sow_outdoor', 'plant_out', 'harvest'];

/** Positive integer id, accepts '12' (URL params) as well as 12. */
const id = z.coerce.number().int().positive();

/** { [name]: id } schema for req.params */
const idParam = (name = 'id') => z.object({ [name]: id });

const requiredText = (max) => z.string().trim().min(1).max(max);

/** Optional text : '' and whitespace-only strings are stored as NULL. */
const optionalText = (max) => z.string().trim().max(max).transform((v) => v || null).nullable().optional();

/** 'YYYY-MM-DD' date, nullable */
const optionalDate = z.iso.date().nullable().optional();

const month = z.coerce.number().int().min(1).max(12);

/** Positive decimal number (meters, m²...), 2 decimals are stored */
const positiveDecimal = z.coerce.number().min(0).max(99999999);

/** For PATCH : a body with at least one field */
const nonEmpty = (schema) => schema.refine((data) => Object.values(data).some((v) => v !== undefined), {
  message: 'At least one field must be provided',
});

/** Smallest shape accepted (m²) */
const MIN_SHAPE_AREA = 0.01;

/**
 * Free shape drawn by the user : 3 to 50 points { x, y } in meters, rounded to the cm,
 * forming a simple polygon (no crossing edges).
 */
const shape = z.array(z.object({
  x: z.coerce.number().min(-10000).max(10000),
  y: z.coerce.number().min(-10000).max(10000),
}))
  .min(3).max(50)
  .transform((points) => points.map((p) => ({ x: Math.round(p.x * 100) / 100, y: Math.round(p.y * 100) / 100 })))
  .refine(isSimplePolygon, { message: 'The shape must be a simple polygon (no crossing edges, no duplicated point)' })
  .refine((points) => polygonArea(points) >= MIN_SHAPE_AREA, { message: 'The shape is too small' });

const today = () => new Date().toISOString().slice(0, 10);

module.exports = {
  SOIL_TYPES,
  LEVELS,
  PLANT_TYPES,
  RELATION_TYPES,
  ROLES,
  PERIOD_TYPES,
  id,
  idParam,
  requiredText,
  optionalText,
  optionalDate,
  month,
  positiveDecimal,
  shape,
  nonEmpty,
  today,
};
