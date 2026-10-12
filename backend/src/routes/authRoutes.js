const express = require('express');
const router  = express.Router();
const authController = require('../controllers/authController');
const validate       = require('../middlewares/validate');
const { limitPerIp } = require('../middlewares/rateLimit');
const { registerSchema, loginSchema, googleLoginSchema, resendVerificationSchema, forgotPasswordSchema } = require('../validators/userValidators');

// brute force protection : 20 attempts per 15 minutes and per IP
const authLimiter = limitPerIp(20);

// each call can send an email
const emailLimiter = limitPerIp(5);

router.post('/register'           , emailLimiter, validate({ body: registerSchema           }), authController.register          );
router.post('/login'              , authLimiter , validate({ body: loginSchema              }), authController.login             );
router.post('/google'             , authLimiter , validate({ body: googleLoginSchema        }), authController.googleLogin       );
router.post('/resend-verification', emailLimiter, validate({ body: resendVerificationSchema }), authController.resendVerification);
router.post('/forgot-password'    , emailLimiter, validate({ body: forgotPasswordSchema     }), authController.forgotPassword    );

// opened in a browser from the verification email
router.get ('/verify-email'       , authController.verifyEmail);
router.get ('/confirm-email'      , authController.confirmEmail);

// web page of the "forgot password" email : the form is posted by the browser (not JSON)
router.get ('/reset-password'     , authController.resetPasswordForm);
router.post('/reset-password'     , authLimiter, express.urlencoded({ extended: false, limit: '10kb' }), authController.resetPassword);

module.exports = router;
