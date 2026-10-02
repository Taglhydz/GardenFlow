const express   = require('express');
const rateLimit = require('express-rate-limit');
const router    = express.Router();
const authController = require('../controllers/authController');
const validate       = require('../middlewares/validate');
const config         = require('../config/env');
const { registerSchema, loginSchema, googleLoginSchema, resendVerificationSchema } = require('../validators/userValidators');

const limiter = (limit) => rateLimit({
  windowMs       : 15 * 60 * 1000,
  limit,
  standardHeaders: 'draft-8',
  legacyHeaders  : false,
  skip           : () => config.isTest,
  handler        : (req, res) => res.status(429).json({ code: 'TOO_MANY_REQUESTS', message: 'Too many attempts, try again later' }),
});

// brute force protection : 20 attempts per 15 minutes and per IP
const authLimiter = limiter(20);

// each call can send an email
const emailLimiter = limiter(5);

router.post('/register'           , authLimiter , validate({ body: registerSchema           }), authController.register          );
router.post('/login'              , authLimiter , validate({ body: loginSchema              }), authController.login             );
router.post('/google'             , authLimiter , validate({ body: googleLoginSchema        }), authController.googleLogin       );
router.post('/resend-verification', emailLimiter, validate({ body: resendVerificationSchema }), authController.resendVerification);

// opened in a browser from the verification email
router.get ('/verify-email'       , authController.verifyEmail);

module.exports = router;
