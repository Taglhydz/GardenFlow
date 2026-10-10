const jwt      = require('jsonwebtoken');
const config   = require('../config/env');
const User     = require('../models/userModel');
const AppError = require('../utils/AppError');

/**
 * Verifies the Bearer token and loads the user from the database.
 * Loading the user on each request means that a deleted account, a role change or revoked tokens
 * (new password, "log out of all devices") take effect immediately, even if the token is not expired.
 * Sets req.user = { id, role }.
 */
const authenticate = async (req, res, next) => {
  const [scheme, token] = (req.headers.authorization || '').split(' ');

  if (scheme !== 'Bearer' || !token) { throw AppError.unauthorized('UNAUTHORIZED', 'No token provided'); }

  let payload;
  try {
    payload = jwt.verify(token, config.jwt.secret, { algorithms: ['HS256'] });
  } catch {
    throw AppError.unauthorized('INVALID_TOKEN', 'Invalid or expired token');
  }

  const user = await User.findSession(payload.sub);

  // check user still exists
  if (!user) { throw AppError.unauthorized('INVALID_TOKEN', 'User no longer exists'); }

  // check token not revoked
  if (payload.ver !== user.token_version) { throw AppError.unauthorized('INVALID_TOKEN', 'Token revoked'); }

  req.user = { id: user.id, role: user.role };

  next();
};

/** Must be used after `authenticate`. */
const requireRole = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user?.role)) { throw AppError.forbidden(); }

  next();
};

const requireAdmin = requireRole('admin');

/** user : { id, role, token_version } (User.findSession) */
const signToken = (user) => jwt.sign(
  { sub: user.id, role: user.role, ver: user.token_version },
  config.jwt.secret,
  { algorithm: 'HS256', expiresIn: config.jwt.expiresIn }
);

module.exports = { authenticate, requireRole, requireAdmin, signToken };
