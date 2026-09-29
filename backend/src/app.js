const config  = require('./config/env');
const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');
const multer  = require('multer');
const routes  = require('./routes');
const { PHOTOS_DIR } = require('./utils/photoStorage');
const { logRequest } = require('./utils/logger');
const { notFoundHandler, errorHandler } = require('./middlewares/errorHandler');

// The app is exported without listening (see server.js) so the tests can use it.
const app = express();

// security headers
app.use(helmet());

// CORS : only needed by Flutter Web, mobile apps are not concerned
app.use(cors(config.corsOrigins.length ? { origin: config.corsOrigins } : {}));

// Support JSON et form-data (text fields only ; the photo upload route reads its own file)
const PHOTO_UPLOAD = '/api/users/me/photo';
app.use(express.json({ limit: '100kb' }));
app.use((req, res, next) => (req.path === PHOTO_UPLOAD ? next() : multer().none()(req, res, next)));

// profile photos : public (random names), the web app loads them from another origin
app.use(
  '/api/uploads/photos',
  helmet.crossOriginResourcePolicy({ policy: 'cross-origin' }),
  express.static(PHOTOS_DIR, { maxAge: '7d', immutable: true, fallthrough: false }),
);

// logger
app.use(logRequest);

// the routes
app.use('/api', routes);

// Management route not found
app.use(notFoundHandler);

// Global error handler (Express 5 forwards errors thrown in async handlers here)
app.use(errorHandler);

module.exports = app;
