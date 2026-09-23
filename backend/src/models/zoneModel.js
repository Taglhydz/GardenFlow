const db = require('../database/db');
const { buildUpdateSet } = require('../utils/sql');

const UPDATABLE = ['name', 'shape', 'area_m2'];

/** The shape is stored as JSON (mysql2 parses it back automatically when reading). */
const serialize = (data) => (data.shape === undefined ? data : { ...data, shape: JSON.stringify(data.shape) });

// Ownership goes through the parcel and the garden : zone -> parcel -> garden.user_id
const Zone = {
  /** The caller must have checked that the parcel belongs to the user. */
  findAllByParcel: async (parcelId) => {
    const [rows] = await db.query('SELECT * FROM zone WHERE parcel_id = ? ORDER BY created_at, id', [parcelId]);
    return rows;
  },

  /** Zones of all the parcels of a garden. The caller must have checked that the garden belongs to the user. */
  findAllByGarden: async (gardenId) => {
    const [rows] = await db.query(
      `SELECT z.* FROM zone z
       JOIN parcel p ON p.id = z.parcel_id
       WHERE p.garden_id = ?
       ORDER BY z.created_at, z.id`,
      [gardenId]
    );
    return rows;
  },

  findOwned: async (id, userId) => {
    const [rows] = await db.query(
      `SELECT z.* FROM zone z
       JOIN parcel p ON p.id = z.parcel_id
       JOIN garden g ON g.id = p.garden_id
       WHERE z.id = ? AND g.user_id = ?`,
      [id, userId]
    );
    return rows[0] || null;
  },

  /** The caller must have checked that the parcel belongs to the user. */
  create: async (parcelId, { name, shape, area_m2 }) => {
    const [result] = await db.query(
      'INSERT INTO zone (parcel_id, name, shape, area_m2) VALUES (?, ?, ?, ?)',
      [parcelId, name, JSON.stringify(shape), area_m2]
    );
    const [rows] = await db.query('SELECT * FROM zone WHERE id = ?', [result.insertId]);
    return rows[0];
  },

  /** The caller must have checked ownership with findOwned. */
  update: async (id, data) => {
    const { clause, values } = buildUpdateSet(serialize(data), UPDATABLE);
    if (clause) {
      await db.query(`UPDATE zone SET ${clause} WHERE id = ?`, [...values, id]);
    }
    const [rows] = await db.query('SELECT * FROM zone WHERE id = ?', [id]);
    return rows[0] || null;
  },

  /** Its crops stay in the parcel (crop.zone_id -> NULL). */
  delete: async (id) => {
    const [result] = await db.query('DELETE FROM zone WHERE id = ?', [id]);
    return result.affectedRows > 0;
  },
};

module.exports = Zone;
