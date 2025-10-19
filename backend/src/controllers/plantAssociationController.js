const PlantAssociation = require('../models/plantAssociationModel');

exports.getAllPlantAssociations = async (req, res) => {
  try {
    const associations = await PlantAssociation.getAll();

    res.status(200).json(associations);

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la récupération des associations de plantes', details: err.message });
  }
};

exports.getPlantAssociationById = async (req, res) => {
  const { id } = req.params;

  try {
    const association = await PlantAssociation.getById(id);

	// check association found
    if (!association) { return res.status(404).json({ error: 'Association non trouvée' }); }

    res.status(200).json(association);

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la récupération de l’association', details: err.message });
  }
};

exports.createPlantAssociation = async (req, res) => {
  const { plant_id_1, plant_id_2, relation_type, comment } = req.body;

  // check required fields
  if (!plant_id_1 || !plant_id_2 || !relation_type) { return res.status(400).json({ error: 'plant_id_1, plant_id_2 et relation_type sont requis' }); }

  const newAssociation = { plant_id_1, plant_id_2, relation_type, comment };

  try {
    const created = await PlantAssociation.create(newAssociation);
	
    res.status(201).json(created);

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la création de l’association', details: err.message });
  }
};

exports.updatePlantAssociation = async (req, res) => {
  const { id } = req.params;
  const { plant_id_1, plant_id_2, relation_type, comment } = req.body;
  const updatedAssociation = { plant_id_1, plant_id_2, relation_type, comment };

  try {
    const result = await PlantAssociation.update(id, updatedAssociation);

	// check association updated
    if (result.affectedRows === 0) { return res.status(404).json({ error: 'Association non trouvée ou déjà supprimée' }); }

    res.status(200).json({ message: 'Association mise à jour avec succès' });

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la mise à jour de l’association', details: err.message });
  }
};

exports.deletePlantAssociation = async (req, res) => {
  const { id } = req.params;

  try {
    const result = await PlantAssociation.softDelete(id);

	// check association deleted
    if (result.affectedRows === 0) { return res.status(404).json({ error: 'Association non trouvée ou déjà supprimée' }); }

    res.status(200).json({ message: 'Association supprimée (soft delete) avec succès' });

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la suppression de l’association', details: err.message });
  }
};
