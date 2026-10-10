const app      = require('./app');
const config   = require('./config/env');
const migrator = require('./database/migrator');

/** null when the database has all the migrations, else what is wrong */
const migrationsProblem = async () => {
  const connection = await migrator.connect();
  try {
    const state = await migrator.status(connection);
    return migrator.problemOf(state)
      ?? (state.pending.length ? `Pending migrations: ${state.pending.map((f) => f.name).join(', ')}. Run \`npm run migrate\`.` : null);
  } finally {
    await connection.end();
  }
};

/**
 * The database must have all the migrations : in production the server refuses to start without them
 * (the code would query columns that don't exist), in development it only warns (even if MySQL is not started yet).
 */
const checkMigrations = async () => {
  let problem;
  try {
    problem = await migrationsProblem();
  } catch (err) {
    problem = `Migrations not checked: ${err.message}`;
  }
  if (!problem) return;

  if (config.isProd) throw new Error(problem);
  console.warn(`⚠️  ${problem}`);
};

checkMigrations()
  .then(() => {
    app.listen(config.port, () => {
      console.log(`🌱 GardenFlow Server running on port ${config.port} (${config.NODE_ENV})`);
      console.log(`📍 API available at http://localhost:${config.port}/api`);
    });
  })
  .catch((err) => {
    console.error(`❌ ${err.message}`);
    process.exit(1);
  });
