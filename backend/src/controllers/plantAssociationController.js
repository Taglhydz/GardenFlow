const PlantAssociation = require('../models/plantAssociationModel');
const AppError         = require('../utils/AppError');

// Reference data : every logged in user can read it, only admins can modify it.

/** GET /plant-associations?plant_id=3 */
exports.getAllPlantAssociations = async (req, res) => {
  res.json(await PlantAssociation.findAll({ plantId: req.valid.query.plant_id }));
};

/** GET /plant-associations/:id */
exports.getPlantAssociationById = async (req, res) => {
  const association = await PlantAssociation.findById(req.valid.params.id);

  // check association found
  if (!association) { throw AppError.notFound('Plant association'); }

  res.json(association);
};

/** POST /plant-associations (admin) - (A, B) and (B, A) are the same association */
exports.createPlantAssociation = async (req, res) => {
  try {
    res.status(201).json(await PlantAssociation.create(req.valid.body));
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') { throw AppError.conflict('ASSOCIATION_ALREADY_EXISTS', 'These two plants already have an association'); }
    throw err;
  }
};

/** PATCH /plant-associations/:id (admin) - relation_type and comment only */
exports.updatePlantAssociation = async (req, res) => {
  const { id } = req.valid.params;

  // check association found
  if (!(await PlantAssociation.findById(id))) { throw AppError.notFound('Plant association'); }

  res.json(await PlantAssociation.update(id, req.valid.body));
};

/** DELETE /plant-associations/:id (admin) */
exports.deletePlantAssociation = async (req, res) => {
  // check association deleted
  if (!(await PlantAssociation.delete(req.valid.params.id))) { throw AppError.notFound('Plant association'); }

  res.status(204).end();
};
