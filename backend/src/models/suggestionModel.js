const db = require('../database/db');

const Suggestion = {
  getAll: () => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM suggestion WHERE deleted_at IS NULL', (err, results) => {
        if (err) return reject(err);
        resolve(results);
      });
    });
  },

  getById: (id) => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM suggestion WHERE id = ? AND deleted_at IS NULL', [id], (err, results) => {
        if (err) return reject(err);
        resolve(results[0]);
      });
    });
  },

  create: (suggestion) => {
    return new Promise((resolve, reject) => {
      db.query('INSERT INTO suggestion (user_id, parcel_id, plant_id, reason) VALUES (?, ?, ?, ?)', [suggestion.user_id, suggestion.parcel_id, suggestion.plant_id, suggestion.reason], (err, result) => {
        if (err) return reject(err);
        resolve({ id: result.insertId, ...suggestion });
      });
    });
  },

  update: (id, suggestion) => {
    return new Promise((resolve, reject) => {
      db.query('UPDATE suggestion SET user_id = ?, parcel_id = ?, plant_id = ?, reason = ? WHERE id = ? AND deleted_at IS NULL', [suggestion.user_id, suggestion.parcel_id, suggestion.plant_id, suggestion.reason, id], (err, result) => {
        if (err) return reject(err);
        resolve(result);
      });
    });
  },

  softDelete: (id) => {
    return new Promise((resolve, reject) => {
      db.query('UPDATE suggestion SET deleted_at = NOW() WHERE id = ?', [id], (err, result) => {
        if (err) return reject(err);
        resolve(result);
      });
    });
  },
};

module.exports = Suggestion;
