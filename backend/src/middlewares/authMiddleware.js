const jwt = require('jsonwebtoken');

module.exports = (req, res, next) => {
  // logique vérif token JWT
  next();
};
