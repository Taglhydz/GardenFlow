const db = require('../database/db');

const Plant = {
  getAll: () => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM plant WHERE deleted_at IS NULL', (err, results) => {
        if (err) return reject(err);
        resolve(results);
      });
    });
  },

  getById: (id) => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM plant WHERE id = ? AND deleted_at IS NULL', [id], (err, results) => {
        if (err) return reject(err);
        resolve(results[0]);
      });
    });
  },

  create: (plant) => {
    return new Promise((resolve, reject) => {
      db.query('INSERT INTO plant (name, type, description, sow_start_month, sow_end_month, harvest_start_month, harvest_end_month, sunlight_need, water_need, preferred_soil, spacing_cm) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [plant.name, plant.type, plant.description, plant.sow_start_month, plant.sow_end_month, plant.harvest_start_month, plant.harvest_end_month, plant.sunlight_need, plant.water_need, plant.preferred_soil, plant.spacing_cm], (err, result) => {
        if (err) return reject(err);
        resolve({ id: result.insertId, ...plant });
      });
    });
  },

  update: (id, plant) => {
    return new Promise((resolve, reject) => {
      db.query('UPDATE plant SET name = ?, type = ?, description = ?, sow_start_month = ?, sow_end_month = ?, harvest_start_month = ?, harvest_end_month = ?, sunlight_need = ?, water_need = ?, preferred_soil = ?, spacing_cm = ? WHERE id = ? AND deleted_at IS NULL', [plant.name, plant.type, plant.description, plant.sow_start_month, plant.sow_end_month, plant.harvest_start_month, plant.harvest_end_month, plant.sunlight_need, plant.water_need, plant.preferred_soil, plant.spacing_cm, id], (err, result) => {
        if (err) return reject(err);
        resolve(result);
      });
    });
  },

  softDelete: (id) => {
    return new Promise((resolve, reject) => {
      db.query('UPDATE plant SET deleted_at = NOW() WHERE id = ?', [id], (err, result) => {
        if (err) return reject(err);
        resolve(result);
      });
    });
  },
};

module.exports = Plant;
