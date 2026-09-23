/**
 * Recreates all tables and loads the reference data.
 *   npm run db:reset        -> database DB_NAME
 *   npm run db:reset:test   -> database DB_NAME_TEST
 * ⚠️  All data in the target database is deleted.
 */
const fs     = require('fs');
const path   = require('path');
const mysql  = require('mysql2/promise');
const config = require('../src/config/env');

const SQL_DIR = path.join(__dirname, '..', 'src', 'database');

const resetDatabase = async ({ withSeed = true } = {}) => {
  const connection = await mysql.createConnection({ ...config.db, multipleStatements: true });

  try {
    await connection.query(fs.readFileSync(path.join(SQL_DIR, 'schema.sql'), 'utf8'));
    if (withSeed) {
      await connection.query(fs.readFileSync(path.join(SQL_DIR, 'seed.sql'), 'utf8'));
    }
  } finally {
    await connection.end();
  }
};

module.exports = { resetDatabase };

if (require.main === module) {
  resetDatabase()
    .then(() => console.log(`✅ Database "${config.db.database}" reset and seeded`))
    .catch((err) => {
      console.error(`❌ Database reset failed: ${err.message}`);
      process.exit(1);
    });
}
