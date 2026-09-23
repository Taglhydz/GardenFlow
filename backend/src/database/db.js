const mysql  = require('mysql2/promise');
const config = require('../config/env');

const pool = mysql.createPool({
  ...config.db,
  waitForConnections: true,
  connectionLimit   : 10,
  queueLimit        : 0,
  // DECIMAL columns are returned as JS numbers instead of strings
  decimalNumbers: true,
  // DATE columns are returned as 'YYYY-MM-DD' strings : avoids timezone shifts
  // (a birthdate 2000-01-01 would otherwise become 1999-12-31T23:00:00Z)
  dateStrings: ['DATE'],
});

module.exports = pool;
