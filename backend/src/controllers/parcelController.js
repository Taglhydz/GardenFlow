const Parcel = require('../models/parcelModel');

exports.getAllParcels = async (req, res) => {
  // TODO: récupérer toutes les parcelles
  res.json({ message: 'getAllParcels endpoint' });
};

exports.getParcelById = async (req, res) => {
  // TODO: récupérer une parcelle par son id
  res.json({ message: 'getParcelById endpoint' });
};

exports.createParcel = async (req, res) => {
  // TODO: créer une parcelle
  res.json({ message: 'createParcel endpoint' });
};

exports.updateParcel = async (req, res) => {
  // TODO: mettre à jour une parcelle
  res.json({ message: 'updateParcel endpoint' });
};

exports.deleteParcel = async (req, res) => {
  // TODO: suppression logique (soft delete)
  res.json({ message: 'deleteParcel endpoint' });
};

exports.getParcelsByGardenId = async (req, res) => {
  // TODO: récupérer toutes les parcelles d'un jardin donné
  res.json({ message: 'getParcelsByGardenId endpoint' });
};
