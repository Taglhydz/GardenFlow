require('dotenv').config({ quiet: true });
const os   = require('os');
const path = require('path');

const NODE_ENV = process.env.NODE_ENV || 'development';
const isTest   = NODE_ENV === 'test';
const isProd   = NODE_ENV === 'production';

const required = ['DB_HOST', 'DB_USER', isTest ? 'DB_NAME_TEST' : 'DB_NAME', 'JWT_SECRET'];
const missing  = required.filter((key) => !process.env[key]);

// fail fast : better to crash at startup than to sign tokens with an undefined secret
if (missing.length > 0) {
  throw new Error(`Missing required environment variables: ${missing.join(', ')} (see .env.example)`);
}

if (process.env.JWT_SECRET.length < 32) {
  // anyone guessing the secret can sign tokens for any account : refused in production
  if (isProd) throw new Error('JWT_SECRET must contain at least 32 random characters (see .env.example)');
  console.warn('⚠️  JWT_SECRET is shorter than 32 characters, use a longer random secret.');
}

/**
 * TRUST_PROXY : number of reverse proxies (nginx...) in front of the server, so that req.ip is the IP of the
 * user and not the one of the proxy (the rate limits count per IP). Empty = no proxy.
 * Also accepts the values of Express ('loopback', a subnet...).
 */
const trustProxy = (() => {
  const value = (process.env.TRUST_PROXY || '').trim();
  if (!value || value === 'false') return false;
  return /^\d+$/.test(value) ? Number(value) : value;
})();

const publicUrl = (process.env.PUBLIC_URL || `http://localhost:${Number(process.env.PORT) || 3000}`).replace(/\/+$/, '');
const corsOrigins = (process.env.CORS_ORIGINS || '').split(',').map((o) => o.trim()).filter(Boolean);

// online : the passwords and the tokens must not travel in clear, the web app must be the only site allowed
if (isProd) {
  if (!publicUrl.startsWith('https://')) console.warn('⚠️  PUBLIC_URL is not https : put the server behind HTTPS in production.');
  if (corsOrigins.length === 0) console.warn('⚠️  CORS_ORIGINS is empty : every website can call the API, set the address of the web app.');
}

module.exports = {
  NODE_ENV,
  isTest,
  isProd,
  isDev: NODE_ENV === 'development',
  port: Number(process.env.PORT) || 3000,
  db: {
    host    : process.env.DB_HOST,
    port    : Number(process.env.DB_PORT) || 3306,
    user    : process.env.DB_USER,
    password: process.env.DB_PASSWORD || '',
    database: isTest ? process.env.DB_NAME_TEST : process.env.DB_NAME,
  },
  jwt: {
    secret   : process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
  },
  // address of this server as seen from a phone or a mail client : used in the links sent by email
  publicUrl,
  // without SMTP_HOST, the emails are printed in the terminal instead of being sent
  smtp: {
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT) || 587,
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASSWORD,
    from: process.env.SMTP_FROM || 'GardenFlow <no-reply@gardenflow.local>',
  },
  // OAuth client ids of the Google Cloud project (the "Web" one, comma separated if several) : the Google
  // tokens sent by the app must be issued for one of them. Empty = Google sign-in disabled
  googleClientIds: (process.env.GOOGLE_CLIENT_ID || '').split(',').map((id) => id.trim()).filter(Boolean),
  corsOrigins,
  trustProxy,
  logResponseData: process.env.LOG_RESPONSE_DATA === 'true',
  // files sent by the users (profile photos) ; the tests use a temporary folder
  uploadsDir: process.env.UPLOADS_DIR
    || (isTest ? path.join(os.tmpdir(), 'gardenflow-test-uploads') : path.resolve(__dirname, '../../uploads')),
};
