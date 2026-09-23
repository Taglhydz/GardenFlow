const db = require('../database/db');
const { buildUpdateSet } = require('../utils/sql');

const UPDATABLE = ['relation_type', 'comment'];

// The plant codes are joined so the app can translate the comment
// (plant_associations.<code_a>__<code_b>, codes sorted alphabetically).
const SELECT = `
  SELECT pa.*, p1.code AS plant_code_1, p2.code AS plant_code_2
  FROM plant_association pa
  JOIN plant p1 ON p1.id = pa.plant_id_1
  JOIN plant p2 ON p2.id = pa.plant_id_2`;

/** Pairs are always stored with plant_id_1 < plant_id_2 (see schema.sql). */
const orderPair = (a, b) => (a < b ? [a, b] : [b, a]);

const PlantAssociation = {
  findAll: async ({ plantId } = {}) => {
    const [rows] = plantId
      ? await db.query(`${SELECT} WHERE pa.plant_id_1 = ? OR pa.plant_id_2 = ? ORDER BY pa.id`, [plantId, plantId])
      : await db.query(`${SELECT} ORDER BY pa.id`);
    return rows;
  },

  findById: async (id) => {
    const [rows] = await db.query(`${SELECT} WHERE pa.id = ?`, [id]);
    return rows[0] || null;
  },

  /** Fails with ER_DUP_ENTRY (-> 409) if the pair already exists, in any order. */
  create: async ({ plant_id_1, plant_id_2, relation_type, comment }) => {
    const [first, second] = orderPair(plant_id_1, plant_id_2);
    const [result] = await db.query(
      'INSERT INTO plant_association (plant_id_1, plant_id_2, relation_type, comment) VALUES (?, ?, ?, ?)',
      [first, second, relation_type, comment ?? null]
    );
    return PlantAssociation.findById(result.insertId);
  },

  update: async (id, data) => {
    const { clause, values } = buildUpdateSet(data, UPDATABLE);
    if (clause) {
      await db.query(`UPDATE plant_association SET ${clause} WHERE id = ?`, [...values, id]);
    }
    return PlantAssociation.findById(id);
  },

  delete: async (id) => {
    const [result] = await db.query('DELETE FROM plant_association WHERE id = ?', [id]);
    return result.affectedRows > 0;
  },
};

module.exports = PlantAssociation;
