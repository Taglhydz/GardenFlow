const db = require('../database/db');
const { buildUpdateSet } = require('../utils/sql');

const UPDATABLE = ['name', 'area_m2', 'pos_x', 'pos_y', 'width', 'length', 'soil_type', 'sunlight', 'moisture'];

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
    const fields  = UPDATABLE.filter((key) => data[key] !== undefined);
    const columns = ['garden_id', ...fields];
    const values  = [gardenId, ...fields.map((key) => data[key])];

    const [result] = await db.query(
      `INSERT INTO parcel (${columns.map((c) => `\`${c}\``).join(', ')}) VALUES (${columns.map(() => '?').join(', ')})`,
      values
    );
    const [rows] = await db.query('SELECT * FROM parcel WHERE id = ?', [result.insertId]);
    return rows[0];
  },

  /** The caller must have checked ownership with findOwned. */
  update: async (id, data) => {
    const { clause, values } = buildUpdateSet(data, UPDATABLE);
    if (clause) {
      await db.query(`UPDATE parcel SET ${clause} WHERE id = ?`, [...values, id]);
    }
    const [rows] = await db.query('SELECT * FROM parcel WHERE id = ?', [id]);
    return rows[0] || null;
  },

  /** Hard delete : crops are removed by ON DELETE CASCADE. */
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
