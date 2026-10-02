const User     = require('../models/userModel');
const AppError = require('../utils/AppError');
const { hashPassword, comparePassword } = require('../utils/hash');
const { signToken } = require('../middlewares/authMiddleware');
const { sendVerificationEmail, sentRecently, verifyToken, confirmEmailChange } = require('../services/emailVerification');
const { verifyEmailPage, isSuccess } = require('../views/verifyEmailPage');
const googleAuth = require('../services/googleAuth');

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

/** Web page showing the result of a link opened from an email */
const sendLinkPage = (req, res, status) => {
  const lang = req.acceptsLanguages('fr', 'en') || 'fr';

  res.status(isSuccess(status) ? 200 : 400)
    .type('html')
    .send(verifyEmailPage(status, lang));
};

/** GET /auth/verify-email?token=... - web page opened from the email */
exports.verifyEmail = async (req, res) => {
  sendLinkPage(req, res, await verifyToken(req.query.token));
};

/** GET /auth/confirm-email?token=... - web page opened from the email sent to the new address (PATCH /users/me/email) */
exports.confirmEmail = async (req, res) => {
  sendLinkPage(req, res, await confirmEmailChange(req.query.token));
};

/** Username of a new Google account : its Google name, else the start of the email ('Tom Vaillant' -> 'tom vaillant') */
const usernameFromGoogle = ({ name, email }) => {
  const fromName  = (name || '').trim().toLowerCase().slice(0, 50);
  const fromEmail = email.split('@')[0].toLowerCase().slice(0, 50);
  if (fromName.length >= 3) return fromName;
  return fromEmail.length >= 3 ? fromEmail : 'gardener';
};

/**
 * POST /auth/google - sign up or log in with the ID token given to the app by Google Sign-In.
 *   - Google account already linked : log in
 *   - an account exists with the same email : the Google account is linked to it
 *   - otherwise : new account, without password, email already verified by Google
 * 201 + created: true for a new account (the app shows the welcome dialog).
 */
exports.googleLogin = async (req, res) => {
  const profile = await googleAuth.verifyIdToken(req.valid.body.id_token);

  if (!profile.email || !profile.emailVerified) {
    throw AppError.unauthorized('GOOGLE_EMAIL_NOT_VERIFIED', 'The email of this Google account is not verified');
  }

  let user    = await User.findByIdentity('google', profile.sub);
  let created = false;

  if (!user) {
    const existing = await User.findByEmailWithPassword(profile.email);

    if (existing) {
      // Google proves the address belongs to this person. An unverified account may have been created by
      // someone else with this email : its password is removed, so that only the owner can log in.
      if (!existing.email_verified_at) {
        await User.updatePassword(existing.id, null);
        await User.markEmailVerified(existing.id);
      }
      user = existing;
    } else {
      user = await User.create({ username: usernameFromGoogle(profile), email: profile.email, passwordHash: null, emailVerified: true });
      created = true;
    }

    await User.addIdentity(user.id, 'google', profile.sub);
    user = await User.findById(user.id);
  }

  res.status(created ? 201 : 200).json({ token: signToken(user), user, created });
};
