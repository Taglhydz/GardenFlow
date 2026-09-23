const db = require('../database/db');
const { buildUpdateSet } = require('../utils/sql');

const FIELDS = [
  'code', 'name', 'type', 'family', 'description', 'days_to_maturity',
  'sunlight_need', 'water_need', 'preferred_soil', 'spacing_cm',
];

/** Adds `periods: [{ type, start_month, end_month }]` to each plant (one query for all plants). */
const attachPeriods = async (plants) => {
  if (plants.length === 0) return plants;

  const [rows] = await db.query(
    'SELECT plant_id, type, start_month, end_month FROM plant_period WHERE plant_id IN (?) ORDER BY plant_id, type, start_month',
    [plants.map((p) => p.id)]
  );

  const byPlant = new Map(plants.map((p) => [p.id, []]));
  for (const { plant_id, ...period } of rows) byPlant.get(plant_id).push(period);

  return plants.map((p) => ({ ...p, periods: byPlant.get(p.id) }));
};

/** Replaces all the periods of a plant (inside the given transaction connection). */
const replacePeriods = async (connection, plantId, periods) => {
  await connection.query('DELETE FROM plant_period WHERE plant_id = ?', [plantId]);
  if (periods.length === 0) return;

  await connection.query(
    'INSERT INTO plant_period (plant_id, type, start_month, end_month) VALUES ?',
    [periods.map((p) => [plantId, p.type, p.start_month, p.end_month])]
  );
};

/** Runs `work(connection)` in a transaction. */
const inTransaction = async (work) => {
  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const result = await work(connection);
    await connection.commit();
    return result;
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    connection.release();
  }
};

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
    return attachPeriods(rows);
  },

  findById: async (id) => {
    const [rows] = await db.query('SELECT * FROM plant WHERE id = ?', [id]);
    if (!rows[0]) return null;
    return (await attachPeriods(rows))[0];
  },

  /** `data.periods` (optional) : [{ type, start_month, end_month }] */
  create: async ({ periods = [], ...data }) => {
    const id = await inTransaction(async (connection) => {
      const fields = FIELDS.filter((key) => data[key] !== undefined);
      const [result] = await connection.query(
        `INSERT INTO plant (${fields.map((f) => `\`${f}\``).join(', ')}) VALUES (${fields.map(() => '?').join(', ')})`,
        fields.map((key) => data[key])
      );
      await replacePeriods(connection, result.insertId, periods);
      return result.insertId;
    });
    return Plant.findById(id);
  },

  /** When `data.periods` is given, it replaces all the periods of the plant. */
  update: async (id, { periods, ...data }) => {
    await inTransaction(async (connection) => {
      const { clause, values } = buildUpdateSet(data, FIELDS);
      if (clause) {
        await connection.query(`UPDATE plant SET ${clause} WHERE id = ?`, [...values, id]);
      }
      if (periods !== undefined) {
        await replacePeriods(connection, id, periods);
      }
    });
    return Plant.findById(id);
  },

  /** Fails with ER_ROW_IS_REFERENCED_2 (-> 409 RESOURCE_IN_USE) if a crop uses the plant. */
  delete: async (id) => {
    const [result] = await db.query('DELETE FROM plant WHERE id = ?', [id]);
    return result.affectedRows > 0;
  },
};

module.exports = Plant;
