const Suggestion = require('../models/suggestionModel');

exports.getAllSuggestions = async (req, res) => {
  try {
    const suggestions = await Suggestion.getAll();

    res.status(200).json(suggestions);

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la récupération des suggestions', details: err.message });
  }
};

exports.getSuggestionById = async (req, res) => {
  const { id } = req.params;

  try {
    const suggestion = await Suggestion.getById(id);

	// check suggestion found
    if (!suggestion) { return res.status(404).json({ error: 'Suggestion non trouvée' }); }

    res.status(200).json(suggestion);

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la récupération de la suggestion', details: err.message });
  }
};

exports.createSuggestion = async (req, res) => {
  const { user_id, parcel_id, plant_id, reason } = req.body;

  // check required fields
  if (!parcel_id || !plant_id || !reason) { return res.status(400).json({ error: 'parcel_id, plant_id et reason sont requis' }); }

  const newSuggestion = { user_id, parcel_id, plant_id, reason };

  try {
    const created = await Suggestion.create(newSuggestion);

    res.status(201).json(created);

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la création de la suggestion', details: err.message });
  }
};

exports.updateSuggestion = async (req, res) => {
  const { id } = req.params;
  const { user_id, parcel_id, plant_id, reason } = req.body;
  const updatedSuggestion = { user_id, parcel_id, plant_id, reason };

  try {
    const result = await Suggestion.update(id, updatedSuggestion);

	// check suggestion deleted or not found
    if (result.affectedRows === 0) { return res.status(404).json({ error: 'Suggestion non trouvée ou déjà supprimée' }); }

    res.status(200).json({ message: 'Suggestion mise à jour avec succès' });

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la mise à jour de la suggestion', details: err.message });
  }
};

exports.deleteSuggestion = async (req, res) => {
  const { id } = req.params;

  try {
    const result = await Suggestion.softDelete(id);

	// check suggestion deleted
    if (result.affectedRows === 0) { return res.status(404).json({ error: 'Suggestion non trouvée ou déjà supprimée' }); }

    res.status(200).json({ message: 'Suggestion supprimée (soft delete) avec succès' });

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la suppression de la suggestion', details: err.message });
  }
};
