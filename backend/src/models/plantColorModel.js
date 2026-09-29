const db = require('../database/db');

const PlantColor = {
  /** [{ plant_id, hue }] of the user */
  findByUser: async (userId) => {
    const [rows] = await db.query('SELECT plant_id, hue FROM plant_color WHERE user_id = ? ORDER BY plant_id', [userId]);
    return rows;
  },

  /** Creates or replaces the color of the plant for the user */
  set: async (userId, plantId, hue) => {
    await db.query(
      'INSERT INTO plant_color (user_id, plant_id, hue) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE hue = VALUES(hue)',
      [userId, plantId, hue]
    );
    return { plant_id: plantId, hue };
  },

  /** Back to the automatic color. Returns false when the plant had no color chosen. */
  delete: async (userId, plantId) => {
    const [result] = await db.query('DELETE FROM plant_color WHERE user_id = ? AND plant_id = ?', [userId, plantId]);
    return result.affectedRows > 0;
  },
};

module.exports = PlantColor;
