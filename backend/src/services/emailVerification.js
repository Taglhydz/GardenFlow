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

module.exports = { sendVerificationEmail, sentRecently, verifyToken };
