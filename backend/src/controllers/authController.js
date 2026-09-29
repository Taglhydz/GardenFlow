const User     = require('../models/userModel');
const AppError = require('../utils/AppError');
const { hashPassword, comparePassword } = require('../utils/hash');
const { signToken } = require('../middlewares/authMiddleware');
const { sendVerificationEmail, sentRecently, verifyToken } = require('../services/emailVerification');
const { verifyEmailPage } = require('../views/verifyEmailPage');

// Compared when the email doesn't exist, so that a login takes the same time
// whether the account exists or not (prevents guessing registered emails).
const DUMMY_HASH = '$2b$10$VYNkVe19xl3i3r5naF7iK.aM50HvSOsP0vYjik/f7pR0LjWQKxQc.';

/** A failed email is only logged : the user can ask for a new one from the app. */
const sendVerificationEmailSafely = (user, lang) => sendVerificationEmail(user, lang)
  .catch((err) => console.error(`❌ Verification email to ${user.email} not sent: ${err.message}`));

/**
 * POST /auth/register - the role is always 'user' (admins are promoted with scripts/set-role.js)
 * No token : the account can log in once the link sent by email has been opened.
 */
exports.register = async (req, res) => {
  const { username, email, password, birthdate, lang } = req.valid.body;

  // check email
  if (await User.findByEmailWithPassword(email)) { throw AppError.conflict('EMAIL_ALREADY_USED', 'Email already in use'); }

  let user;
  try {
    user = await User.create({ username, email, passwordHash: await hashPassword(password), birthdate });
  } catch (err) {
    // two simultaneous registrations with the same email
    if (err.code === 'ER_DUP_ENTRY') { throw AppError.conflict('EMAIL_ALREADY_USED', 'Email already in use'); }
    throw err;
  }

  await sendVerificationEmailSafely(user, lang);

  res.status(201).json({ user });
};

/** POST /auth/login */
exports.login = async (req, res) => {
  const { email, password } = req.valid.body;

  const found = await User.findByEmailWithPassword(email);
  const valid = await comparePassword(password, found?.password_hash ?? DUMMY_HASH);

  // same error for unknown email and wrong password
  if (!found || !valid) { throw AppError.unauthorized('INVALID_CREDENTIALS', 'Invalid email or password'); }

  // only told once the password is right, so it doesn't reveal which emails are registered
  if (!found.email_verified_at) { throw new AppError(403, 'EMAIL_NOT_VERIFIED', 'Open the link sent by email before logging in'); }

  const { password_hash, ...user } = found;

  res.json({ token: signToken(user), user });
};

/** POST /auth/resend-verification - always 204, so it doesn't reveal which emails are registered */
exports.resendVerification = async (req, res) => {
  const { email, lang } = req.valid.body;

  const user = await User.findVerificationByEmail(email);

  // not awaited : the answer takes the same time whether an email is sent or not
  if (user && !user.email_verified_at && !sentRecently(user)) sendVerificationEmailSafely(user, lang);

  res.status(204).end();
};

/** GET /auth/verify-email?token=... - web page opened from the email */
exports.verifyEmail = async (req, res) => {
  const status = await verifyToken(req.query.token);
  const lang   = req.acceptsLanguages('fr', 'en') || 'fr';

  res.status(status === 'verified' || status === 'already_verified' ? 200 : 400)
    .type('html')
    .send(verifyEmailPage(status, lang));
};
