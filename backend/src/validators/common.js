const { z } = require('zod');

// Must stay in sync with the ENUMs of schema.sql
const SOIL_TYPES     = ['standard', 'clay', 'sandy', 'loamy', 'humus', 'chalky'];
const LEVELS         = ['low', 'medium', 'high'];
const PLANT_TYPES    = ['vegetable', 'fruit', 'herb', 'flower'];
const RELATION_TYPES = ['positive', 'negative'];
const ROLES          = ['user', 'admin'];

/** Positive integer id, accepts '12' (URL params) as well as 12. */
const id = z.coerce.number().int().positive();

/** { [name]: id } schema for req.params */
const idParam = (name = 'id') => z.object({ [name]: id });

const requiredText = (max) => z.string().trim().min(1).max(max);

/** Optional text : '' and whitespace-only strings are stored as NULL. */
const optionalText = (max) => z.string().trim().max(max).transform((v) => v || null).nullable().optional();

/** 'YYYY-MM-DD' date, nullable */
const optionalDate = z.iso.date().nullable().optional();

const month = z.coerce.number().int().min(1).max(12).nullable().optional();

/** Positive decimal number (meters, m²...), 2 decimals are stored */
const positiveDecimal = z.coerce.number().min(0).max(99999999);

/** For PATCH : a body with at least one field */
const nonEmpty = (schema) => schema.refine((data) => Object.values(data).some((v) => v !== undefined), {
  message: 'At least one field must be provided',
});

const today = () => new Date().toISOString().slice(0, 10);

module.exports = {
  SOIL_TYPES,
  LEVELS,
  PLANT_TYPES,
  RELATION_TYPES,
  ROLES,
  id,
  idParam,
  requiredText,
  optionalText,
  optionalDate,
  month,
  positiveDecimal,
  nonEmpty,
  today,
};
