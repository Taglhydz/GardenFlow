const config   = require('../config/env');
const AppError = require('../utils/AppError');

// MySQL errors that are caused by the client, not by the server
const MYSQL_ERRORS = {
  ER_DUP_ENTRY              : () => AppError.conflict('DUPLICATE_ENTRY', 'This resource already exists'),
  ER_NO_REFERENCED_ROW_2    : () => AppError.badRequest('INVALID_REFERENCE', 'A referenced resource does not exist'),
  ER_ROW_IS_REFERENCED_2    : () => AppError.conflict('RESOURCE_IN_USE', 'This resource is used elsewhere and cannot be deleted'),
  ER_CHECK_CONSTRAINT_VIOLATED: () => AppError.badRequest('VALIDATION_ERROR', 'A value is out of the allowed range'),
};

const notFoundHandler = (req, res) => {
  res.status(404).json({ code: 'ROUTE_NOT_FOUND', message: `Route ${req.method} ${req.originalUrl} not found` });
};

// eslint-disable-next-line no-unused-vars
const errorHandler = (err, req, res, next) => {
  let error = err;

  if (!(error instanceof AppError)) {
    if (MYSQL_ERRORS[err.code]) {
      error = MYSQL_ERRORS[err.code]();
    } else if (err.type === 'entity.parse.failed') {
      error = AppError.badRequest('INVALID_JSON', 'Malformed JSON body');
    } else if (err.type === 'entity.too.large') {
      error = new AppError(413, 'PAYLOAD_TOO_LARGE', 'Request body is too large');
    } else if (err.name === 'MulterError') {
      error = AppError.badRequest('INVALID_FORM_DATA', err.message);
    } else {
      // unexpected error : log it and never leak its details to the client
      if (!config.isTest) console.error(err);
      error = new AppError(500, 'INTERNAL_ERROR', 'Internal server error');
    }
  }

  const body = { code: error.code, message: error.message };
  if (error.details) body.details = error.details;

  res.status(error.status).json(body);
};

module.exports = { notFoundHandler, errorHandler };
