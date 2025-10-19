const PlantAssociation = require('../models/plantAssociationModel');

exports.getAllPlantAssociations = async (req, res) => {
  // TODO: récupérer toutes les associations de plantes
  res.json({ message: 'getAllPlantAssociations endpoint' });
};

exports.getPlantAssociationById = async (req, res) => {
  // TODO: récupérer une association par son id
  res.json({ message: 'getPlantAssociationById endpoint' });
};

exports.createPlantAssociation = async (req, res) => {
  // TODO: créer une association
  res.json({ message: 'createPlantAssociation endpoint' });
};

exports.updatePlantAssociation = async (req, res) => {
  // TODO: mettre à jour une association
  res.json({ message: 'updatePlantAssociation endpoint' });
};

exports.deletePlantAssociation = async (req, res) => {
  // TODO: suppression logique (soft delete)
  res.json({ message: 'deletePlantAssociation endpoint' });
};
