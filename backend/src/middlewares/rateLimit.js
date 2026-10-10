const rateLimit = require('express-rate-limit');
const config    = require('../config/env');

const tooMany = (req, res) => res.status(429).json({ code: 'TOO_MANY_REQUESTS', message: 'Too many attempts, try again later' });

/** At most `limit` requests per 15 minutes and per IP (routes without login) */
const limitPerIp = (limit) => rateLimit({
  windowMs       : 15 * 60 * 1000,
  limit,
  standardHeaders: 'draft-8',
  legacyHeaders  : false,
  skip           : () => config.isTest,
  handler        : tooMany,
});

/**
 * At most `limit` requests per 15 minutes and per account : must be used after `authenticate`.
 * A stolen token can't try passwords forever, nor send emails to any address in a loop.
 */
const limitPerUser = (limit) => rateLimit({
  windowMs       : 15 * 60 * 1000,
  limit,
  standardHeaders: 'draft-8',
  legacyHeaders  : false,
  skip           : () => config.isTest,
  keyGenerator   : (req) => `user-${req.user.id}`,
  handler        : tooMany,
});

module.exports = { limitPerIp, limitPerUser };
