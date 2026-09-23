const config = require('../config/env');

const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  dim: '\x1b[2m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
  gray: '\x1b[90m'
};

// never print these fields, even in development
const SENSITIVE_FIELDS = ['password', 'current_password', 'new_password', 'token'];

function getStatusColor(status) {
  if (status >= 200 && status < 300) return colors.green;
  if (status >= 300 && status < 400) return colors.cyan;
  if (status >= 400 && status < 500) return colors.yellow;
  if (status >= 500) return colors.red;
  return colors.white;
}

function getMethodColor(method) {
  switch (method) {
    case 'GET': return colors.blue;
    case 'POST': return colors.green;
    case 'PUT': return colors.yellow;
    case 'PATCH': return colors.magenta;
    case 'DELETE': return colors.red;
    default: return colors.white;
  }
}

function formatTimestamp() {
  const now = new Date();
  return now.toLocaleString('fr-FR', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });
}

function redact(data) {
  if (!data || typeof data !== 'object') return data;
  if (Array.isArray(data)) return data.map(redact);

  return Object.fromEntries(Object.entries(data).map(([key, value]) => [
    key,
    SENSITIVE_FIELDS.includes(key) ? '***' : redact(value),
  ]));
}

function logRequest(req, res, next) {
  if (config.isTest) return next();

  const startTime = Date.now();
  const timestamp = formatTimestamp();
  let responseData = null;

  // capture the response body only when explicitly asked
  if (config.logResponseData) {
    const originalJson = res.json;
    res.json = function (data) {
      responseData = data;
      return originalJson.call(this, data);
    };
  }

  res.on('finish', () => {
    const duration = Date.now() - startTime;
    const statusCode = res.statusCode;

    console.log(
      `${colors.gray}[${timestamp}]${colors.reset} ` +
      `${getMethodColor(req.method)}${req.method.padEnd(6)}${colors.reset} ` +
      `${colors.white}${req.originalUrl.padEnd(50)}${colors.reset} ` +
      `${getStatusColor(statusCode)}${statusCode.toString().padStart(3)}${colors.reset} ` +
      `${colors.gray}${duration.toString().padStart(4)}ms${colors.reset}`
    );

    if (responseData) {
      console.log(`${colors.dim}Response:${colors.reset}`, redact(responseData));
    }

    // client errors : show what was sent (without secrets or headers) to ease debugging
    if (statusCode >= 400 && statusCode < 500 && config.isDev) {
      console.log(`${colors.dim}Request body:${colors.reset}`, redact(req.body));
    }
  });

  next();
}

module.exports = { logRequest };
