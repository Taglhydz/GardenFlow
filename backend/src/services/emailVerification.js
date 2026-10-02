const crypto = require('crypto');
const config = require('../config/env');
const User   = require('../models/userModel');
const mailer = require('../utils/mailer');

const TOKEN_TTL_MS = 24 * 60 * 60 * 1000;

// a new email can be asked 1 minute after the previous one
const RESEND_COOLDOWN_MS = 60 * 1000;

// only the hash is stored : someone reading the database cannot verify an address with it
const hashToken = (token) => crypto.createHash('sha256').update(token).digest('hex');

/** Creates a new link (the previous one stops working) and sends it to user.email. */
const sendVerificationEmail = async (user, lang) => {
  const token = crypto.randomBytes(32).toString('hex');
  await User.startEmailVerification(user.id, hashToken(token), new Date(Date.now() + TOKEN_TTL_MS));

  await mailer.sendVerificationEmail({
    to      : user.email,
    username: user.username,
    url     : `${config.publicUrl}/api/auth/verify-email?token=${token}`,
    lang,
  });
};

/** true when the last email was sent less than RESEND_COOLDOWN_MS ago */
const sentRecently = (user) => user.verification_expires_at
  && new Date(user.verification_expires_at).getTime() - TOKEN_TTL_MS > Date.now() - RESEND_COOLDOWN_MS;

/**
 * Opens a link : 'verified' the first time, then 'already_verified' each time the link is opened again.
 * 'expired' / 'invalid' otherwise.
 */
const verifyToken = async (token) => {
  if (typeof token !== 'string' || !/^[0-9a-f]{64}$/.test(token)) return 'invalid';

  const user = await User.findByVerificationToken(hashToken(token));

  if (!user) return 'invalid';
  if (user.email_verified_at) return 'already_verified';
  if (new Date(user.verification_expires_at).getTime() < Date.now()) return 'expired';

  await User.markEmailVerified(user.id);
  return 'verified';
};

/** Puts newEmail on hold (the previous link stops working) and sends it a link to confirm the change. */
const sendEmailChangeEmail = async (user, newEmail, lang) => {
  const token = crypto.randomBytes(32).toString('hex');
  await User.startEmailChange(user.id, newEmail, hashToken(token), new Date(Date.now() + TOKEN_TTL_MS));

  await mailer.sendEmailChangeEmail({
    to      : newEmail,
    username: user.username,
    url     : `${config.publicUrl}/api/auth/confirm-email?token=${token}`,
    lang,
  });
};

/**
 * Opens a change link : 'email_changed' the first time and each time the link is opened again,
 * 'email_taken' if another account took the address meanwhile, 'change_expired' / 'invalid' otherwise.
 */
const confirmEmailChange = async (token) => {
  if (typeof token !== 'string' || !/^[0-9a-f]{64}$/.test(token)) return 'invalid';

  const user = await User.findByEmailChangeToken(hashToken(token));

  if (!user) return 'invalid';
  if (!user.pending_email) return 'email_changed';
  if (new Date(user.email_change_expires_at).getTime() < Date.now()) return 'change_expired';

  try {
    await User.applyEmailChange(user.id);
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') return 'email_taken';
    throw err;
  }
  return 'email_changed';
};

module.exports = { sendVerificationEmail, sentRecently, verifyToken, sendEmailChangeEmail, confirmEmailChange };
