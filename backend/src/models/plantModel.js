const db = require('../database/db');
const { buildUpdateSet } = require('../utils/sql');

const FIELDS = [
  'code', 'name', 'type', 'description',
  'sow_start_month', 'sow_end_month', 'harvest_start_month', 'harvest_end_month',
  'sunlight_need', 'water_need', 'preferred_soil', 'spacing_cm',
];

const Plant = {
  findAll: async ({ type, search } = {}) => {
    const conditions = [];
    const values     = [];

    if (type) {
      conditions.push('type = ?');
      values.push(type);
    }
    if (search) {
      // name is in French, code in English : search both
      conditions.push('(name LIKE ? OR code LIKE ?)');
      values.push(`%${search}%`, `%${search}%`);
    }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
    const [rows] = await db.query(`SELECT * FROM plant ${where} ORDER BY name`, values);
    return rows;
  },

  findById: async (id) => {
    const [rows] = await db.query('SELECT * FROM plant WHERE id = ?', [id]);
    return rows[0] || null;
  },

  create: async (data) => {
    const fields = FIELDS.filter((key) => data[key] !== undefined);
    const [result] = await db.query(
      `INSERT INTO plant (${fields.map((f) => `\`${f}\``).join(', ')}) VALUES (${fields.map(() => '?').join(', ')})`,
      fields.map((key) => data[key])
    );
    return Plant.findById(result.insertId);
  },

  update: async (id, data) => {
    const { clause, values } = buildUpdateSet(data, FIELDS);
    if (clause) {
      await db.query(`UPDATE plant SET ${clause} WHERE id = ?`, [...values, id]);
    }
    return Plant.findById(id);
  },

  /** Fails with ER_ROW_IS_REFERENCED_2 (-> 409 RESOURCE_IN_USE) if a crop uses the plant. */
  delete: async (id) => {
    const [result] = await db.query('DELETE FROM plant WHERE id = ?', [id]);
    return result.affectedRows > 0;
  },
};

module.exports = Plant;
