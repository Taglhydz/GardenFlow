const fs     = require('fs');
const path   = require('path');
const crypto = require('crypto');
const mysql  = require('mysql2/promise');
const config = require('../config/env');

// Database migrations : numbered SQL files in ./migrations, applied once and in order.
// The table schema_migrations remembers the applied ones, with a checksum of their content :
// a migration already applied must never be modified (add a new one instead).
//
// MySQL can't roll back a CREATE / ALTER TABLE : a migration that fails halfway must be fixed by hand.
// Keep each migration small, and try it on a copy of the data before running it in production.

const MIGRATIONS_DIR = path.join(__dirname, 'migrations');

/** '003_add_password_reset.sql' : 3 digits, lowercase words separated by _ */
const FILE_NAME = /^\d{3}_[a-z0-9_]+\.sql$/;

/**
 * The migrations of a database created before the migrations existed (with the old schema.sql + seed.sql) :
 * `npm run db:baseline` marks them as applied without running them.
 */
const BASELINE = ['001_initial_schema.sql', '002_plant_catalog.sql'];

const TABLE = 'schema_migrations';

/** The line endings don't count : a file checked out with CRLF on Windows has the same checksum */
const checksum = (sql) => crypto.createHash('sha256').update(sql.replace(/\r\n/g, '\n')).digest('hex');

/** The migration files, in order : [{ name, sql, checksum }] */
const readMigrations = () => {
  const names = fs.readdirSync(MIGRATIONS_DIR).filter((name) => name.endsWith('.sql')).sort();

  const invalid = names.filter((name) => !FILE_NAME.test(name));
  if (invalid.length) throw new Error(`Invalid migration file names (expected 001_some_name.sql): ${invalid.join(', ')}`);

  const numbers = names.map((name) => name.slice(0, 3));
  const twice = numbers.filter((n, i) => numbers.indexOf(n) !== i);
  if (twice.length) throw new Error(`Several migrations have the same number: ${[...new Set(twice)].join(', ')}`);

  return names.map((name) => {
    const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, name), 'utf8');
    return { name, sql, checksum: checksum(sql) };
  });
};

/** Connection able to run a whole file (several statements) */
const connect = () => mysql.createConnection({ ...config.db, multipleStatements: true });

const tableExists = async (connection, table) => {
  const [rows] = await connection.query(
    'SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?',
    [table]
  );
  return rows.length > 0;
};

/** Tables of the database, except the migrations table */
const appTables = async (connection) => {
  const [rows] = await connection.query(
    'SELECT TABLE_NAME AS name FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME <> ?',
    [TABLE]
  );
  return rows.map((row) => row.name);
};

const createTable = (connection) => connection.query(`
  CREATE TABLE IF NOT EXISTS ${TABLE} (
    name       VARCHAR(255) PRIMARY KEY,
    checksum   CHAR(64)     NOT NULL,
    applied_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
  ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci`);

/**
 * What is applied and what is not :
 *   - tracked  : false when the database has no migrations table yet
 *   - legacy   : tables exist without the migrations table (database created before the migrations)
 *   - pending  : files not applied yet, in order
 *   - modified : files applied, then modified (their checksum changed)
 *   - missing  : applied, but their file doesn't exist anymore
 */
const status = async (connection) => {
  const files   = readMigrations();
  const tracked = await tableExists(connection, TABLE);
  const applied = tracked ? (await connection.query(`SELECT name, checksum FROM ${TABLE} ORDER BY name`))[0] : [];
  const byName  = new Map(applied.map((row) => [row.name, row.checksum]));

  return {
    tracked,
    legacy  : !tracked && (await appTables(connection)).length > 0,
    applied : applied.map((row) => row.name),
    pending : files.filter((file) => !byName.has(file.name)),
    modified: files.filter((file) => byName.has(file.name) && byName.get(file.name) !== file.checksum).map((file) => file.name),
    missing : applied.map((row) => row.name).filter((name) => !files.some((file) => file.name === name)),
  };
};

/** Problems that forbid applying the migrations, null when everything is fine */
const problemOf = (state) => {
  if (state.legacy) {
    return 'The database has tables but no migrations history (created before the migrations): run `npm run db:baseline` once.';
  }
  if (state.modified.length) {
    return `Applied migrations were modified: ${state.modified.join(', ')}. Restore them and add a new migration instead.`;
  }
  if (state.missing.length) {
    return `Applied migrations have no file anymore: ${state.missing.join(', ')}.`;
  }
  return null;
};

/** Applies the pending migrations in order. Returns the names of the applied ones. */
const migrate = async (connection, { log = () => {} } = {}) => {
  const state = await status(connection);
  const problem = problemOf(state);
  if (problem) throw new Error(problem);

  await createTable(connection);
  const done = [];
  for (const file of state.pending) {
    log(`▶ ${file.name}`);
    try {
      await connection.query(file.sql);
    } catch (err) {
      throw new Error(`${file.name} failed: ${err.message}. The migrations before it are applied; `
        + 'check what this one changed before running it again.');
    }
    await connection.query(`INSERT INTO ${TABLE} (name, checksum) VALUES (?, ?)`, [file.name, file.checksum]);
    done.push(file.name);
  }
  return done;
};

/** Database created before the migrations : the BASELINE migrations are marked as applied, without running them. */
const baseline = async (connection) => {
  const state = await status(connection);
  if (state.tracked) throw new Error('The database already has a migrations history: nothing to do.');
  if (!state.legacy) throw new Error('The database is empty: run `npm run migrate` instead.');

  const files = readMigrations().filter((file) => BASELINE.includes(file.name));
  await createTable(connection);
  for (const file of files) {
    await connection.query(`INSERT INTO ${TABLE} (name, checksum) VALUES (?, ?)`, [file.name, file.checksum]);
  }
  return files.map((file) => file.name);
};

/** Deletes every table of the database (the migrations history too) */
const dropAllTables = async (connection) => {
  const tables = [...(await appTables(connection)), ...((await tableExists(connection, TABLE)) ? [TABLE] : [])];
  if (!tables.length) return;
  await connection.query(`SET FOREIGN_KEY_CHECKS = 0; DROP TABLE ${tables.map((t) => `\`${t}\``).join(', ')}; SET FOREIGN_KEY_CHECKS = 1;`);
};

/** Creates the file of a new migration with the next number, returns its path */
const createMigrationFile = (description) => {
  const slug = description.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
  if (!slug) throw new Error('Give a short description, e.g. npm run migrate:new -- add password reset');

  const files = readMigrations();
  const next = String(files.length ? Number(files.at(-1).name.slice(0, 3)) + 1 : 1).padStart(3, '0');
  const name = `${next}_${slug}.sql`;
  const file = path.join(MIGRATIONS_DIR, name);

  fs.writeFileSync(file, `-- Migration ${next} : ${description}\n-- Never modify this file once it is applied somewhere : add a new migration instead.\n\n`);
  return file;
};

module.exports = { connect, status, problemOf, migrate, baseline, dropAllTables, createMigrationFile, checksum };
