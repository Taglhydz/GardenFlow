const AppError = require('../utils/AppError');

const formatIssues = (issues) => issues.map((issue) => ({
  field  : issue.path.join('.'),
  message: issue.message,
}));

/**
 * Validates and sanitizes req.body / req.params / req.query with zod schemas.
 * Unknown fields are stripped, so controllers only receive whitelisted data.
 * The parsed values are exposed in req.valid = { body, params, query }.
 *
 * router.post('/', validate({ body: createGardenSchema }), controller.create)
 */
const validate = (schemas) => (req, res, next) => {
  req.valid = {};

  for (const part of ['params', 'query', 'body']) {
    if (!schemas[part]) continue;

    const result = schemas[part].safeParse(req[part] ?? {});

    if (!result.success) {
      throw AppError.badRequest('VALIDATION_ERROR', `Invalid request ${part}`, formatIssues(result.error.issues));
    }

    req.valid[part] = result.data;
  }

  next();
};

module.exports = validate;
