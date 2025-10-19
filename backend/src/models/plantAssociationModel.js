const db = require('../database/db');

const PlantAssociation = {
  getAll: () => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM plant_association WHERE deleted_at IS NULL', (err, results) => {
        if (err) return reject(err);
        resolve(results);
      });
    });
  },

  getById: (id) => {
    return new Promise((resolve, reject) => {
      db.query('SELECT * FROM plant_association WHERE id = ? AND deleted_at IS NULL', [id], (err, results) => {
        if (err) return reject(err);
        resolve(results[0]);
      });
    });
  },

  create: (association) => {
    return new Promise((resolve, reject) => {
      db.query('INSERT INTO plant_association (plant_id_1, plant_id_2, relation_type, comment) VALUES (?, ?, ?, ?)', [association.plant_id_1, association.plant_id_2, association.relation_type, association.comment], (err, result) => {
        if (err) return reject(err);
        resolve({ id: result.insertId, ...association });
      });
    });
  },

  update: (id, association) => {
    return new Promise((resolve, reject) => {
      db.query('UPDATE plant_association SET plant_id_1 = ?, plant_id_2 = ?, relation_type = ?, comment = ? WHERE id = ? AND deleted_at IS NULL', [association.plant_id_1, association.plant_id_2, association.relation_type, association.comment, id], (err, result) => {
        if (err) return reject(err);
        resolve(result);
      });
    });
  },

  softDelete: (id) => {
    return new Promise((resolve, reject) => {
      db.query('UPDATE plant_association SET deleted_at = NOW() WHERE id = ?', [id], (err, result) => {
        if (err) return reject(err);
        resolve(result);
      });
    });
  },
};

module.exports = PlantAssociation;
