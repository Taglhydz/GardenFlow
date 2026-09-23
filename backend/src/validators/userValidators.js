const { z } = require('zod');
const { ROLES, requiredText, optionalDate, nonEmpty, today } = require('./common');

const email = z.string().trim().toLowerCase().pipe(z.email().max(255));

// bcrypt only uses the first 72 bytes of a password
const password = z.string().min(8, 'Password must contain at least 8 characters').max(72);

const username = requiredText(50).min(3, 'Username must contain at least 3 characters');

const birthdate = optionalDate.refine((v) => !v || v <= today(), { message: 'Birthdate cannot be in the future' });

const registerSchema = z.object({
  username,
  email,
  password,
  birthdate,
});

const loginSchema = z.object({
  email,
  password: z.string().min(1),
});

const updateMeSchema = nonEmpty(z.object({
  username: username.optional(),
  email   : email.optional(),
  birthdate,
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

module.exports = {
  registerSchema,
  loginSchema,
  updateMeSchema,
  changePasswordSchema,
  adminUpdateUserSchema,
};
