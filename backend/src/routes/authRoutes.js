const express   = require('express');
const rateLimit = require('express-rate-limit');
const router    = express.Router();
const authController = require('../controllers/authController');
const validate       = require('../middlewares/validate');
const config         = require('../config/env');
const { registerSchema, loginSchema } = require('../validators/userValidators');

// brute force protection : 20 attempts per 15 minutes and per IP
const authLimiter = rateLimit({
  windowMs       : 15 * 60 * 1000,
  limit          : 20,
  standardHeaders: 'draft-8',
  legacyHeaders  : false,
  skip           : () => config.isTest,
  handler        : (req, res) => res.status(429).json({ code: 'TOO_MANY_REQUESTS', message: 'Too many attempts, try again later' }),
});

router.post('/register', authLimiter, validate({ body: registerSchema }), authController.register);
router.post('/login'   , authLimiter, validate({ body: loginSchema    }), authController.login   );

module.exports = router;
