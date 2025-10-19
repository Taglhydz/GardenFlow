const db = require('../database/db');

const Parcel = {
  getAll: () => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM parcel WHERE deleted_at IS NULL', (err, results) => {
        if (err) return reject(err);
        resolve(results);
      });
    });
  },

  getById: (id) => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM parcel WHERE id = ? AND deleted_at IS NULL', [id], (err, results) => {
        if (err) return reject(err);
        resolve(results[0]);
      });
    });
  },

  getByGardenId: (garden_id) => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM parcel WHERE garden_id = ? AND deleted_at IS NULL', [garden_id], (err, results) => {
        if (err) return reject(err);
        resolve(results);
      });
    });
  },

  create: (parcel) => {
    return new Promise((resolve, reject) => {
      db.query('INSERT INTO parcel (garden_id, name, area_m2, pos_x, pos_y, width, length, soil_type, sunlight, moisture) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [parcel.garden_id, parcel.name, parcel.area_m2, parcel.pos_x, parcel.pos_y, parcel.width, parcel.length, parcel.soil_type, parcel.sunlight, parcel.moisture], (err, result) => {
        if (err) return reject(err);
        resolve({ id: result.insertId, ...parcel });
      });
    });
  },

  update: (id, parcel) => {
    return new Promise((resolve, reject) => {
      db.query('UPDATE parcel SET name = ?, area_m2 = ?, pos_x = ?, pos_y = ?, width = ?, length = ?, soil_type = ?, sunlight = ?, moisture = ? WHERE id = ? AND deleted_at IS NULL', [parcel.name, parcel.area_m2, parcel.pos_x, parcel.pos_y, parcel.width, parcel.length, parcel.soil_type, parcel.sunlight, parcel.moisture, id], (err, result) => {
        if (err) return reject(err);
        resolve(result);
      });
    });
  },

  softDelete: (id) => {
    return new Promise((resolve, reject) => {
      db.query('UPDATE parcel SET deleted_at = NOW() WHERE id = ?', [id], (err, result) => {
        if (err) return reject(err);
        resolve(result);
      });
    });
  },
};

module.exports = Parcel;
