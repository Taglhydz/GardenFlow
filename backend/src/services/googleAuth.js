const { OAuth2Client } = require('google-auth-library');
const config   = require('../config/env');
const AppError = require('../utils/AppError');

// downloads and caches the public keys of Google to check the signature of the tokens
const client = new OAuth2Client();

const googleAuth = {
  /**
   * Checks an ID token given to the app by Google Sign-In : signature, expiry, and that it was issued
   * for our Google Cloud project (audience). Never trust an email sent by the app without this.
   * Returns { sub, email, emailVerified, name }.
   */
  verifyIdToken: async (idToken) => {
    if (config.googleClientIds.length === 0) {
      throw new AppError(503, 'GOOGLE_NOT_CONFIGURED', 'Google sign-in is not configured on the server (GOOGLE_CLIENT_ID)');
    }

    let payload;
    try {
      const ticket = await client.verifyIdToken({ idToken, audience: config.googleClientIds });
      payload = ticket.getPayload();
    } catch (err) {
      if (!config.isTest) console.warn(`⚠️  Google token refused: ${err.message}`);
      throw AppError.unauthorized('INVALID_GOOGLE_TOKEN', 'Invalid Google token');
    }

    return {
      sub          : payload.sub,
      email        : payload.email?.toLowerCase() ?? null,
      emailVerified: payload.email_verified === true,
      name         : payload.name || payload.given_name || null,
    };
  },
};

// the functions are read from this object at call time, so the tests can spy on them
module.exports = googleAuth;
