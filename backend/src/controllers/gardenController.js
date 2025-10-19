const Garden = require('../models/gardenModel');

exports.getAllGardens = async (req, res) => {
  // TODO: récupérer tous les jardins
  res.json({ message: 'getAllGardens endpoint' });
};

exports.getGardenById = async (req, res) => {
  // TODO: récupérer un jardin par son id
  res.json({ message: 'getGardenById endpoint' });
};

exports.createGarden = async (req, res) => {
  // TODO: créer un jardin
  res.json({ message: 'createGarden endpoint' });
};

exports.updateGarden = async (req, res) => {
  // TODO: mettre à jour un jardin
  res.json({ message: 'updateGarden endpoint' });
};

exports.deleteGarden = async (req, res) => {
  // TODO: suppression logique (soft delete)
  res.json({ message: 'deleteGarden endpoint' });
};

exports.getGardensByUserId = async (req, res) => {
  // TODO: récupérer tous les jardins d'un utilisateur donné
  res.json({ message: 'getGardensByUserId endpoint' });
};
