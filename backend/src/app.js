const config  = require('./config/env');
const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');
const multer  = require('multer');
const routes  = require('./routes');
const { logRequest } = require('./utils/logger');
const { notFoundHandler, errorHandler } = require('./middlewares/errorHandler');

// The app is exported without listening (see server.js) so the tests can use it.
const app = express();

// security headers
app.use(helmet());

// CORS : only needed by Flutter Web, mobile apps are not concerned
app.use(cors(config.corsOrigins.length ? { origin: config.corsOrigins } : {}));

// Support JSON et form-data
app.use(express.json({ limit: '100kb' }));
app.use(multer().none());

// logger
app.use(logRequest);

// the routes
app.use('/api', routes);

// Management route not found
app.use(notFoundHandler);

// Global error handler (Express 5 forwards errors thrown in async handlers here)
app.use(errorHandler);

module.exports = app;
