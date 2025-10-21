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

function logRequest(req, res, next) {
  const startTime = Date.now();
  const timestamp = formatTimestamp();
  
  // capture de la réponse
  const originalJson = res.json;
  let responseData = null;
  
  res.json = function(data) {
    responseData = data;
    return originalJson.call(this, data);
  };
  
  const originalEnd = res.end;
  res.end = function(...args) {
    const endTime = Date.now();
    const duration = endTime - startTime;
    const statusCode = res.statusCode;
    
    const methodColor = getMethodColor(req.method);
    const statusColor = getStatusColor(statusCode);
    
    console.log(
      `${colors.gray}[${timestamp}]${colors.reset} ` +
      `${methodColor}${req.method.padEnd(6)}${colors.reset} ` +
      `${colors.white}${req.originalUrl.padEnd(50)}${colors.reset} ` +
      `${statusColor}${statusCode.toString().padStart(3)}${colors.reset} ` +
      `${colors.gray}${duration.toString().padStart(4)}ms${colors.reset}`
    );
    
    if (process.env.LOG_RESPONSE_DATA === 'true' && responseData) {
      console.log(`${colors.dim}Response:${colors.reset}`, responseData);
    }
    
    if (statusCode >= 400) {
      const isExpectedConflict = statusCode === 409 && (
        req.originalUrl.includes('/register') || 
        req.originalUrl.includes('/auth')
      );
      
      if (!isExpectedConflict) {
        console.log(`${colors.red}Error Details:${colors.reset}`, {
          path: req.originalUrl,
          method: req.method,
          query: req.query,
          body: req.body,
          headers: req.headers
        });
      }
    }
    
    return originalEnd.apply(this, args);
  };
  
  next();
}

module.exports = { logRequest };
