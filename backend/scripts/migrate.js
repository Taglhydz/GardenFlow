/**
 * Database migrations (see src/database/migrator.js) :
 *   npm run migrate                       -> applies the pending migrations to DB_NAME
 *   npm run migrate:status                -> shows what is applied and what is pending
 *   npm run migrate:new -- <description>  -> creates the next migration file, to fill in
 *   npm run db:baseline                   -> once, for a database created before the migrations
 */
const config   = require('../src/config/env');
const migrator = require('../src/database/migrator');

const commands = {
  up: async (connection) => {
    const done = await migrator.migrate(connection, { log: console.log });
    console.log(done.length
      ? `✅ ${done.length} migration(s) applied to "${config.db.database}"`
      : `✅ "${config.db.database}" is up to date`);
  },

  status: async (connection) => {
    const state = await migrator.status(connection);
    console.log(`Database "${config.db.database}"`);
    for (const name of state.applied) console.log(`  ✔ ${name}${state.modified.includes(name) ? '  ⚠️ modified since' : ''}`);
    for (const file of state.pending) console.log(`  … ${file.name}  (pending)`);
    const problem = migrator.problemOf(state);
    if (problem) console.log(`⚠️  ${problem}`);
  },

  baseline: async (connection) => {
    const names = await migrator.baseline(connection);
    console.log(`✅ Marked as applied without running them: ${names.join(', ')}`);
    console.log('   Run `npm run migrate` to apply the next ones.');
  },
};

const main = async () => {
  const [command = 'up', ...args] = process.argv.slice(2);

  // creating a file doesn't need the database
  if (command === 'new') {
    console.log(`✅ Created ${migrator.createMigrationFile(args.join(' '))}`);
    return;
  }

  if (!commands[command]) throw new Error(`Unknown command "${command}" (up, status, baseline, new)`);

  const connection = await migrator.connect();
  try {
    await commands[command](connection);
  } finally {
    await connection.end();
  }
};

main().catch((err) => {
  console.error(`❌ ${err.message}`);
  process.exit(1);
});
