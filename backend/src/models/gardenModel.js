const db = require('../database/db');
const { buildUpdateSet } = require('../utils/sql');

const UPDATABLE = ['name', 'location', 'description'];

// Every query is scoped to the owner : a garden of another user is "not found".
const Garden = {
  findAllByUser: async (userId) => {
    const [rows] = await db.query('SELECT * FROM garden WHERE user_id = ? ORDER BY created_at, id', [userId]);
    return rows;
  },

  findOwned: async (id, userId) => {
    const [rows] = await db.query('SELECT * FROM garden WHERE id = ? AND user_id = ?', [id, userId]);
    return rows[0] || null;
  },

  create: async (userId, { name, location, description }) => {
    const [result] = await db.query(
      'INSERT INTO garden (user_id, name, location, description) VALUES (?, ?, ?, ?)',
      [userId, name, location ?? null, description ?? null]
    );
    return Garden.findOwned(result.insertId, userId);
  },

  update: async (id, userId, data) => {
    const { clause, values } = buildUpdateSet(data, UPDATABLE);
    if (clause) {
      await db.query(`UPDATE garden SET ${clause} WHERE id = ? AND user_id = ?`, [...values, id, userId]);
    }
    return Garden.findOwned(id, userId);
  },

  /** Hard delete : parcels and crops are removed by ON DELETE CASCADE. */
  delete: async (id, userId) => {
    const [result] = await db.query('DELETE FROM garden WHERE id = ? AND user_id = ?', [id, userId]);
    return result.affectedRows > 0;
  },
};

module.exports = Garden;
