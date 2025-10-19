const db = require('../database/db');

const User = {
  getAll: () => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM user WHERE deleted_at IS NULL', (err, results) => {
        if (err) return reject(err);
        resolve(results);
      });
    });
  },

  getById: (id) => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM user WHERE id = ? AND deleted_at IS NULL', [id], (err, results) => {
        if (err) return reject(err);
        resolve(results[0]);
      });
    });
  },

  getByEmail: (email) => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM user WHERE email = ? AND deleted_at IS NULL', [email], (err, results) => {
        if (err) return reject(err);
        resolve(results[0]);
      });
    });
  },

  create: (user) => {
    return new Promise((resolve, reject) => {
      db.query('INSERT INTO user (username, email, password, birthdate, role) VALUES (?, ?, ?, ?, ?)', [user.username, user.email, user.password, user.birthdate, user.role || 'user'], (err, result) => {
        if (err) return reject(err);
        resolve({ id: result.insertId, ...user });
      });
    });
  },

  update: (id, user) => {
    return new Promise((resolve, reject) => {
      db.query('UPDATE user SET username = ?, email = ?, password = ?, birthdate = ?, role = ? WHERE id = ? AND deleted_at IS NULL', [user.username, user.email, user.password, user.birthdate, user.role, id], (err, result) => {
        if (err) return reject(err);
        resolve(result);
      });
    });
  },

  softDelete: (id) => {
    return new Promise((resolve, reject) => {
      db.query('UPDATE user SET deleted_at = NOW() WHERE id = ?', [id], (err, result) => {
        if (err) return reject(err);
        resolve(result);
      });
    });
  },
};

module.exports = User;
