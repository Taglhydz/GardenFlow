const db = require('../database/db');
const { buildUpdateSet } = require('../utils/sql');

// password_hash is never selected, except by findByEmailWithPassword / findPasswordHash
const PUBLIC_COLUMNS = 'id, username, email, birthdate, role, created_at, updated_at';
const UPDATABLE      = ['username', 'email', 'birthdate', 'role'];

const User = {
  findAll: async () => {
    const [rows] = await db.query(`SELECT ${PUBLIC_COLUMNS} FROM user ORDER BY id`);
    return rows;
  },

  findById: async (id) => {
    const [rows] = await db.query(`SELECT ${PUBLIC_COLUMNS} FROM user WHERE id = ?`, [id]);
    return rows[0] || null;
  },

  findByEmailWithPassword: async (email) => {
    const [rows] = await db.query(`SELECT ${PUBLIC_COLUMNS}, password_hash FROM user WHERE email = ?`, [email]);
    return rows[0] || null;
  },

  findPasswordHash: async (id) => {
    const [rows] = await db.query('SELECT password_hash FROM user WHERE id = ?', [id]);
    return rows[0]?.password_hash || null;
  },

  create: async ({ username, email, passwordHash, birthdate }) => {
    const [result] = await db.query(
      'INSERT INTO user (username, email, password_hash, birthdate) VALUES (?, ?, ?, ?)',
      [username, email, passwordHash, birthdate ?? null]
    );
    return User.findById(result.insertId);
  },

  update: async (id, data) => {
    const { clause, values } = buildUpdateSet(data, UPDATABLE);
    if (clause) {
      await db.query(`UPDATE user SET ${clause} WHERE id = ?`, [...values, id]);
    }
    return User.findById(id);
  },

  updatePassword: async (id, passwordHash) => {
    await db.query('UPDATE user SET password_hash = ? WHERE id = ?', [passwordHash, id]);
  },

  /** Hard delete : gardens, parcels and crops are removed by ON DELETE CASCADE. */
  delete: async (id) => {
    const [result] = await db.query('DELETE FROM user WHERE id = ?', [id]);
    return result.affectedRows > 0;
  },
};

module.exports = User;
