/**
 * Error with an HTTP status and a stable machine-readable code.
 * The Flutter app translates `code` (errors.<code> in the translation files),
 * `message` is a readable English fallback for developers.
 */
class AppError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.status  = status;
    this.code    = code;
    this.details = details;
  }

  static badRequest(code, message, details) { return new AppError(400, code, message, details); }
  static unauthorized(code = 'UNAUTHORIZED', message = 'Authentication required') { return new AppError(401, code, message); }
  static forbidden(message = 'You are not allowed to do this') { return new AppError(403, 'FORBIDDEN', message); }
  static notFound(resource = 'Resource') { return new AppError(404, 'NOT_FOUND', `${resource} not found`); }
  static conflict(code, message) { return new AppError(409, code, message); }
}

module.exports = AppError;
