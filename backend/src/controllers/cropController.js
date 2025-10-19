const Crop = require('../models/cropModel');

exports.getAllCrops = async (req, res) => {
  try {
    const crops = await Crop.getAll();

    res.status(200).json(crops);

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la récupération des cultures', details: err.message });
  }
};

exports.getCropById = async (req, res) => {
  const { id } = req.params;
  try {
    const crop = await Crop.getById(id);

	// check crop found
    if (!crop) { return res.status(404).json({ error: 'Culture non trouvée' }); }

    res.status(200).json(crop);

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la récupération de la culture', details: err.message });
  }
};

exports.createCrop = async (req, res) => {
  const { parcel_id, plant_id, sow_date, expected_harvest_date, actual_harvest_date, comment } = req.body;
  
  // check required fields
  if (!parcel_id || !plant_id) { return res.status(400).json({ error: 'parcel_id et plant_id sont requis' }); }

  const newCrop = { parcel_id, plant_id, sow_date, expected_harvest_date, actual_harvest_date, comment };

  try {
    const created = await Crop.create(newCrop);

    res.status(201).json(created);

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la création de la culture', details: err.message });
  }
};

exports.updateCrop = async (req, res) => {
  const { id } = req.params;
  const { parcel_id, plant_id, sow_date, expected_harvest_date, actual_harvest_date, comment } = req.body;
  const updatedCrop = { parcel_id, plant_id, sow_date, expected_harvest_date, actual_harvest_date, comment };

  try {
    const result = await Crop.update(id, updatedCrop);

	// check crop updated
    if (result.affectedRows === 0) { return res.status(404).json({ error: 'Culture non trouvée ou déjà supprimée' }); }

    res.status(200).json({ message: 'Culture mise à jour avec succès' });

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la mise à jour de la culture', details: err.message });
  }
};

exports.deleteCrop = async (req, res) => {
  const { id } = req.params;
  
  try {
    const result = await Crop.softDelete(id);

	// check crop deleted
    if (result.affectedRows === 0) { return res.status(404).json({ error: 'Culture non trouvée ou déjà supprimée' }); }

    res.status(200).json({ message: 'Culture supprimée (soft delete) avec succès' });

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la suppression de la culture', details: err.message });
  }
};
