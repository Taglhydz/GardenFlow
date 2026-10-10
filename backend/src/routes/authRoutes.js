const express = require('express');
const router  = express.Router();
const authController = require('../controllers/authController');
const validate       = require('../middlewares/validate');
const { limitPerIp } = require('../middlewares/rateLimit');
const { registerSchema, loginSchema, googleLoginSchema, resendVerificationSchema } = require('../validators/userValidators');

// brute force protection : 20 attempts per 15 minutes and per IP
const authLimiter = limitPerIp(20);

// each call can send an email
const emailLimiter = limitPerIp(5);

router.post('/register'           , emailLimiter, validate({ body: registerSchema           }), authController.register          );
router.post('/login'              , authLimiter , validate({ body: loginSchema              }), authController.login             );
router.post('/google'             , authLimiter , validate({ body: googleLoginSchema        }), authController.googleLogin       );
router.post('/resend-verification', emailLimiter, validate({ body: resendVerificationSchema }), authController.resendVerification);

// opened in a browser from the verification email
router.get ('/verify-email'       , authController.verifyEmail);
router.get ('/confirm-email'      , authController.confirmEmail);

module.exports = router;
