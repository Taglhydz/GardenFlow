const db = require('../database/db');
const { buildUpdateSet } = require('../utils/sql');

// password_hash is never selected, except by findByEmailWithPassword / findPasswordHash
const PUBLIC_COLUMNS = 'id, username, email, birthdate, role, avatar, photo, created_at, updated_at';
const UPDATABLE      = ['username', 'email', 'birthdate', 'role', 'avatar', 'photo'];

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

  /** What the level is computed from (services/levelService.js) : account age and the crops of all the gardens. */
  levelStats: async (id) => {
    const [[row]] = await db.query(
      `SELECT DATEDIFF(NOW(), u.created_at)          AS account_days,
              COUNT(c.id)                            AS planted,
              COUNT(c.actual_harvest_date)           AS harvested,
              COUNT(DISTINCT c.plant_id)             AS plants,
              COUNT(DISTINCT YEAR(COALESCE(c.sow_date, c.created_at)) * 10 + QUARTER(COALESCE(c.sow_date, c.created_at))) AS seasons
       FROM user u
       LEFT JOIN garden g ON g.user_id = u.id
       LEFT JOIN parcel p ON p.garden_id = g.id
       LEFT JOIN crop c   ON c.parcel_id = p.id
       WHERE u.id = ?
       GROUP BY u.id`,
      [id]
    );
    return {
      account_days: Number(row.account_days),
      planted     : Number(row.planted),
      harvested   : Number(row.harvested),
      plants      : Number(row.plants),
      seasons     : Number(row.seasons),
    };
  },

  /** Hard delete : gardens, parcels and crops are removed by ON DELETE CASCADE. */
  delete: async (id) => {
    const [result] = await db.query('DELETE FROM user WHERE id = ?', [id]);
    return result.affectedRows > 0;
  },
};

module.exports = User;
