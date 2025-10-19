const Plant = require('../models/plantModel');

exports.getAllPlants = async (req, res) => {
  // TODO: récupérer toutes les plantes
  res.json({ message: 'getAllPlants endpoint' });
};

exports.getPlantById = async (req, res) => {
  // TODO: récupérer une plante par son id
  res.json({ message: 'getPlantById endpoint' });
};

exports.createPlant = async (req, res) => {
  // TODO: créer une plante
  res.json({ message: 'createPlant endpoint' });
};

exports.updatePlant = async (req, res) => {
  // TODO: mettre à jour une plante
  res.json({ message: 'updatePlant endpoint' });
};

exports.deletePlant = async (req, res) => {
  // TODO: suppression logique (soft delete)
  res.json({ message: 'deletePlant endpoint' });
};
