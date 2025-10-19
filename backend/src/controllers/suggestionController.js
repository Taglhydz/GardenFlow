const Suggestion = require('../models/suggestionModel');

exports.getAllSuggestions = async (req, res) => {
  // TODO: récupérer toutes les suggestions
  res.json({ message: 'getAllSuggestions endpoint' });
};

exports.getSuggestionById = async (req, res) => {
  // TODO: récupérer une suggestion par son id
  res.json({ message: 'getSuggestionById endpoint' });
};

exports.createSuggestion = async (req, res) => {
  // TODO: créer une suggestion
  res.json({ message: 'createSuggestion endpoint' });
};

exports.updateSuggestion = async (req, res) => {
  // TODO: mettre à jour une suggestion
  res.json({ message: 'updateSuggestion endpoint' });
};

exports.deleteSuggestion = async (req, res) => {
  // TODO: suppression logique (soft delete)
  res.json({ message: 'deleteSuggestion endpoint' });
};
