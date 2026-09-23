const db = require('../database/db');
const { buildUpdateSet } = require('../utils/sql');

const UPDATABLE = ['name', 'pos_x', 'pos_y', 'shape', 'area_m2', 'soil_type', 'sunlight', 'moisture'];

/** The shape is stored as JSON (mysql2 parses it back automatically when reading). */
const serialize = (data) => (data.shape === undefined ? data : { ...data, shape: JSON.stringify(data.shape) });

// Ownership goes through the garden : parcel -> garden.user_id
const Parcel = {
  /** The caller must have checked that the garden belongs to the user. */
  findAllByGarden: async (gardenId) => {
    const [rows] = await db.query('SELECT * FROM parcel WHERE garden_id = ? ORDER BY created_at, id', [gardenId]);
    return rows;
  },

  findOwned: async (id, userId) => {
    const [rows] = await db.query(
      `SELECT p.* FROM parcel p
       JOIN garden g ON g.id = p.garden_id
       WHERE p.id = ? AND g.user_id = ?`,
      [id, userId]
    );
    return rows[0] || null;
  },

  /** The caller must have checked that the garden belongs to the user. */
  create: async (gardenId, data) => {
    const values  = serialize(data);
    const fields  = UPDATABLE.filter((key) => values[key] !== undefined);
    const columns = ['garden_id', ...fields];

    const [result] = await db.query(
      `INSERT INTO parcel (${columns.map((c) => `\`${c}\``).join(', ')}) VALUES (${columns.map(() => '?').join(', ')})`,
      [gardenId, ...fields.map((key) => values[key])]
    );
    const [rows] = await db.query('SELECT * FROM parcel WHERE id = ?', [result.insertId]);
    return rows[0];
  },

  /** The caller must have checked ownership with findOwned. */
  update: async (id, data) => {
    const { clause, values } = buildUpdateSet(serialize(data), UPDATABLE);
    if (clause) {
      await db.query(`UPDATE parcel SET ${clause} WHERE id = ?`, [...values, id]);
    }
    const [rows] = await db.query('SELECT * FROM parcel WHERE id = ?', [id]);
    return rows[0] || null;
  },

  /** Hard delete : zones and crops are removed by ON DELETE CASCADE. */
  deleteOwned: async (id, userId) => {
    const [result] = await db.query(
      `DELETE p FROM parcel p
       JOIN garden g ON g.id = p.garden_id
       WHERE p.id = ? AND g.user_id = ?`,
      [id, userId]
    );
    return result.affectedRows > 0;
  },
};

module.exports = Parcel;
