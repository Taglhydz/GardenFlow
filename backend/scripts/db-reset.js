/**
 * Deletes all the tables, then applies all the migrations (tables + plant catalog).
 *   npm run db:reset        -> database DB_NAME
 *   npm run db:reset:test   -> database DB_NAME_TEST
 * ⚠️  All data in the target database is deleted. Refused in production.
 */
const config   = require('../src/config/env');
const migrator = require('../src/database/migrator');

const resetDatabase = async () => {
  if (config.isProd) throw new Error('db:reset deletes all the data: refused in production (NODE_ENV=production)');

  const connection = await migrator.connect();
  try {
    await migrator.dropAllTables(connection);
    await migrator.migrate(connection);
  } finally {
    await connection.end();
  }
};

module.exports = { resetDatabase };

if (require.main === module) {
  resetDatabase()
    .then(() => console.log(`✅ Database "${config.db.database}" reset, all migrations applied`))
    .catch((err) => {
      console.error(`❌ Database reset failed: ${err.message}`);
      process.exit(1);
    });
}
