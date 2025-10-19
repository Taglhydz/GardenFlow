const db = require('../database/db');

const Crop = {
  getAll: () => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM crop WHERE deleted_at IS NULL', (err, results) => {
        if (err) return reject(err);
        resolve(results);
      });
    });
  },

  getById: (id) => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM crop WHERE id = ? AND deleted_at IS NULL', [id], (err, results) => {
        if (err) return reject(err);
        resolve(results[0]);
      });
    });
  },

  getByParcelId: (parcel_id) => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM crop WHERE parcel_id = ? AND deleted_at IS NULL', [parcel_id], (err, results) => {
        if (err) return reject(err);
        resolve(results);
      });
    });
  },

  create: (crop) => {
    return new Promise((resolve, reject) => {
      db.query('INSERT INTO crop (parcel_id, plant_id, sow_date, expected_harvest_date, actual_harvest_date, comment) VALUES (?, ?, ?, ?, ?, ?)', [crop.parcel_id, crop.plant_id, crop.sow_date, crop.expected_harvest_date, crop.actual_harvest_date, crop.comment], (err, result) => {
        if (err) return reject(err);
        resolve({ id: result.insertId, ...crop });
      });
    });
  },

  update: (id, crop) => {
    return new Promise((resolve, reject) => {
      db.query('UPDATE crop SET parcel_id = ?, plant_id = ?, sow_date = ?, expected_harvest_date = ?, actual_harvest_date = ?, comment = ? WHERE id = ? AND deleted_at IS NULL', [crop.parcel_id, crop.plant_id, crop.sow_date, crop.expected_harvest_date, crop.actual_harvest_date, crop.comment, id], (err, result) => {
        if (err) return reject(err);
        resolve(result);
      });
    });
  },

  softDelete: (id) => {
    return new Promise((resolve, reject) => {
      db.query('UPDATE crop SET deleted_at = NOW() WHERE id = ?', [id], (err, result) => {
        if (err) return reject(err);
        resolve(result);
      });
    });
  },
};

module.exports = Crop;
