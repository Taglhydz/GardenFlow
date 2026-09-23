const db = require('../database/db');
const { buildUpdateSet } = require('../utils/sql');

const UPDATABLE = ['plant_id', 'sow_date', 'expected_harvest_date', 'actual_harvest_date', 'comment'];

// Ownership goes through the parcel and the garden : crop -> parcel -> garden.user_id
const Crop = {
  /** The caller must have checked that the parcel belongs to the user. */
  findAllByParcel: async (parcelId) => {
    const [rows] = await db.query('SELECT * FROM crop WHERE parcel_id = ? ORDER BY created_at, id', [parcelId]);
    return rows;
  },

  findOwned: async (id, userId) => {
    const [rows] = await db.query(
      `SELECT c.* FROM crop c
       JOIN parcel p ON p.id = c.parcel_id
       JOIN garden g ON g.id = p.garden_id
       WHERE c.id = ? AND g.user_id = ?`,
      [id, userId]
    );
    return rows[0] || null;
  },

  /** The caller must have checked that the parcel belongs to the user. */
  create: async (parcelId, crop) => {
    const [result] = await db.query(
      `INSERT INTO crop (parcel_id, plant_id, sow_date, expected_harvest_date, actual_harvest_date, comment)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [parcelId, crop.plant_id, crop.sow_date ?? null, crop.expected_harvest_date ?? null, crop.actual_harvest_date ?? null, crop.comment ?? null]
    );
    const [rows] = await db.query('SELECT * FROM crop WHERE id = ?', [result.insertId]);
    return rows[0];
  },

  /** The caller must have checked ownership with findOwned. */
  update: async (id, data) => {
    const { clause, values } = buildUpdateSet(data, UPDATABLE);
    if (clause) {
      await db.query(`UPDATE crop SET ${clause} WHERE id = ?`, [...values, id]);
    }
    const [rows] = await db.query('SELECT * FROM crop WHERE id = ?', [id]);
    return rows[0] || null;
  },

  deleteOwned: async (id, userId) => {
    const [result] = await db.query(
      `DELETE c FROM crop c
       JOIN parcel p ON p.id = c.parcel_id
       JOIN garden g ON g.id = p.garden_id
       WHERE c.id = ? AND g.user_id = ?`,
      [id, userId]
    );
    return result.affectedRows > 0;
  },
};

module.exports = Crop;
