const jwt      = require('jsonwebtoken');
const config   = require('../config/env');
const User     = require('../models/userModel');
const AppError = require('../utils/AppError');

/**
 * Verifies the Bearer token and loads the user from the database.
 * Loading the user on each request means that a deleted account or a role change
 * takes effect immediately, even if the token is still valid.
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

  const user = await User.findById(payload.sub);

  // check user still exists
  if (!user) { throw AppError.unauthorized('INVALID_TOKEN', 'User no longer exists'); }

  req.user = { id: user.id, role: user.role };

  next();
};

/** Must be used after `authenticate`. */
const requireRole = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user?.role)) { throw AppError.forbidden(); }

  next();
};

const requireAdmin = requireRole('admin');

const signToken = (user) => jwt.sign(
  { sub: user.id, role: user.role },
  config.jwt.secret,
  { algorithm: 'HS256', expiresIn: config.jwt.expiresIn }
);

module.exports = { authenticate, requireRole, requireAdmin, signToken };
