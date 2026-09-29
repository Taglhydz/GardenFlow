const { z } = require('zod');
const { ROLES, AVATARS, requiredText, optionalDate, nonEmpty, today } = require('./common');

const email = z.string().trim().toLowerCase().pipe(z.email().max(255));

// bcrypt only uses the first 72 bytes of a password.
// Same rules in the app (frontend/lib/utils/validators.dart) : must stay in sync
const password = z.string()
  .min(10, 'Password must contain at least 10 characters')
  .max(72)
  .regex(/\p{Ll}/u, 'Password must contain a lowercase letter')
  .regex(/\p{Lu}/u, 'Password must contain an uppercase letter')
  .regex(/\p{Nd}/u, 'Password must contain a digit')
  .regex(/[^\p{L}\p{Nd}\s]/u, 'Password must contain a symbol');

// language of the emails sent to the user
const lang = z.enum(['fr', 'en']).optional();

// stored in lowercase ('Tom le plus Beau' -> 'tom le plus beau'), the app capitalizes it for display
const username = requiredText(50).min(3, 'Username must contain at least 3 characters').toLowerCase();

const birthdate = optionalDate.refine((v) => !v || v <= today(), { message: 'Birthdate cannot be in the future' });

const registerSchema = z.object({
  username,
  email,
  password,
  birthdate,
  lang,
});

const resendVerificationSchema = z.object({
  email,
  lang,
});

const loginSchema = z.object({
  email,
  password: z.string().min(1),
});

// avatar : a plant avatar (it replaces the photo), null = none
const updateMeSchema = nonEmpty(z.object({
  username: username.optional(),
  email   : email.optional(),
  birthdate,
  avatar  : z.enum(AVATARS).nullable().optional(),
  lang,
}));

const changePasswordSchema = z.object({
  current_password: z.string().min(1),
  new_password    : password,
});

const adminUpdateUserSchema = nonEmpty(z.object({
  username: username.optional(),
  email   : email.optional(),
  role    : z.enum(ROLES).optional(),
}));

// hue of the color chosen for a plant (degrees)
const plantColorSchema = z.object({
  hue: z.coerce.number().int().min(0).max(359),
});

module.exports = {
  plantColorSchema,
  registerSchema,
  resendVerificationSchema,
  loginSchema,
  updateMeSchema,
  changePasswordSchema,
  adminUpdateUserSchema,
};
