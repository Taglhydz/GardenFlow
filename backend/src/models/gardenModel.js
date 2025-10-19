const db = require('../database/db');

const Garden = {
  getAll: () => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM garden WHERE deleted_at IS NULL', (err, results) => {
        if (err) return reject(err);
        resolve(results);
      });
    });
  },

  getById: (id) => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM garden WHERE id = ? AND deleted_at IS NULL', [id], (err, results) => {
        if (err) return reject(err);
        resolve(results[0]);
      });
    });
  },

  getByUserId: (user_id) => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM garden WHERE user_id = ? AND deleted_at IS NULL', [user_id], (err, results) => {
        if (err) return reject(err);
        resolve(results);
      });
    });
  },

  create: (garden) => {
    return new Promise((resolve, reject) => {
      db.query('INSERT INTO garden (user_id, name, location, description) VALUES (?, ?, ?, ?)', [garden.user_id, garden.name, garden.location, garden.description], (err, result) => {
        if (err) return reject(err);
        resolve({ id: result.insertId, ...garden });
      });
    });
  },

  update: (id, garden) => {
    return new Promise((resolve, reject) => {
      db.query('UPDATE garden SET name = ?, location = ?, description = ? WHERE id = ? AND deleted_at IS NULL', [garden.name, garden.location, garden.description, id], (err, result) => {
        if (err) return reject(err);
        resolve(result);
      });
    });
  },

  softDelete: (id) => {
    return new Promise((resolve, reject) => {
      db.query('UPDATE garden SET deleted_at = NOW() WHERE id = ?', [id], (err, result) => {
        if (err) return reject(err);
        resolve(result);
      });
    });
  },
};

module.exports = Garden;
