const Crop = require('../models/cropModel');

exports.getAllCrops = async (req, res) => {
  // TODO: récupérer toutes les cultures
  res.json({ message: 'getAllCrops endpoint' });
};

exports.getCropById = async (req, res) => {
  // TODO: récupérer une culture par son id
  res.json({ message: 'getCropById endpoint' });
};

exports.createCrop = async (req, res) => {
  // TODO: créer une culture
  res.json({ message: 'createCrop endpoint' });
};

exports.updateCrop = async (req, res) => {
  // TODO: mettre à jour une culture
  res.json({ message: 'updateCrop endpoint' });
};

exports.deleteCrop = async (req, res) => {
  // TODO: suppression logique (soft delete)
  res.json({ message: 'deleteCrop endpoint' });
};
