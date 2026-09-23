require('dotenv').config({ quiet: true });

const NODE_ENV = process.env.NODE_ENV || 'development';
const isTest   = NODE_ENV === 'test';

const required = ['DB_HOST', 'DB_USER', isTest ? 'DB_NAME_TEST' : 'DB_NAME', 'JWT_SECRET'];
const missing  = required.filter((key) => !process.env[key]);

// fail fast : better to crash at startup than to sign tokens with an undefined secret
if (missing.length > 0) {
  throw new Error(`Missing required environment variables: ${missing.join(', ')} (see .env.example)`);
}

if (process.env.JWT_SECRET.length < 32) {
  console.warn('⚠️  JWT_SECRET is shorter than 32 characters, use a longer random secret.');
}

module.exports = {
  NODE_ENV,
  isTest,
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
  corsOrigins    : (process.env.CORS_ORIGINS || '').split(',').map((o) => o.trim()).filter(Boolean),
  logResponseData: process.env.LOG_RESPONSE_DATA === 'true',
};
