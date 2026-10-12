const crypto = require('crypto');
const config = require('../config/env');
const User   = require('../models/userModel');
const mailer = require('../utils/mailer');
const { hashPassword } = require('../utils/hash');
const { hashToken } = require('./emailVerification');

// short : the link gives the account to whoever opens it
const TOKEN_TTL_MS = 60 * 60 * 1000;

// a new email can be asked 1 minute after the previous one
const RESEND_COOLDOWN_MS = 60 * 1000;

const isTokenFormat = (token) => typeof token === 'string' && /^[0-9a-f]{64}$/.test(token);

/**
 * "Forgot password" for user (User.findPasswordResetByEmail) : a link to choose a new password,
 * or for an account created with Google (no password), an email telling to log in with Google.
 */
const sendPasswordResetEmail = async (user, lang) => {
  if (!user.has_password) {
    await mailer.sendGoogleAccountEmail({ to: user.email, username: user.username, lang });
    return;
  }

  // the last link is less than 1 minute old : it is still in the mailbox
  if (user.password_reset_expires_at
    && new Date(user.password_reset_expires_at).getTime() - TOKEN_TTL_MS > Date.now() - RESEND_COOLDOWN_MS) return;

  const token = crypto.randomBytes(32).toString('hex');
  await User.startPasswordReset(user.id, hashToken(token), new Date(Date.now() + TOKEN_TTL_MS));

  await mailer.sendPasswordResetEmail({
    to      : user.email,
    username: user.username,
    url     : `${config.publicUrl}/api/auth/reset-password?token=${token}`,
    lang,
  });
};

/** { status: 'valid', user } (the form can be shown), or status 'expired' / 'invalid' (unknown, or already used) */
const findReset = async (token) => {
  if (!isTokenFormat(token)) return { status: 'invalid' };

  const user = await User.findByPasswordResetToken(hashToken(token));

  if (!user) return { status: 'invalid' };
  if (new Date(user.password_reset_expires_at).getTime() < Date.now()) return { status: 'expired' };
  return { status: 'valid', user };
};

/** 'valid', 'expired' or 'invalid' */
const checkResetToken = async (token) => (await findReset(token)).status;

/** The password of the account of the link becomes `password` (already validated) : 'password_changed', 'expired' or 'invalid' */
const resetPassword = async (token, password) => {
  const { status, user } = await findReset(token);
  if (status !== 'valid') return status;

  await User.resetPassword(user.id, await hashPassword(password));
  return 'password_changed';
};

module.exports = { sendPasswordResetEmail, checkResetToken, resetPassword };
