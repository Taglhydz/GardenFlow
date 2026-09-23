const Plant    = require('../models/plantModel');
const AppError = require('../utils/AppError');

// Reference catalog : every logged in user can read it, only admins can modify it.

/** Turns a duplicate code into a clear error. */
const handleDuplicateCode = (err) => {
  if (err.code === 'ER_DUP_ENTRY') { throw AppError.conflict('PLANT_CODE_ALREADY_USED', 'A plant with this code already exists'); }
  throw err;
};

/** GET /plants?type=vegetable&search=tom */
exports.getAllPlants = async (req, res) => {
  res.json(await Plant.findAll(req.valid.query));
};

/** GET /plants/:id */
exports.getPlantById = async (req, res) => {
  const plant = await Plant.findById(req.valid.params.id);

  // check plant found
  if (!plant) { throw AppError.notFound('Plant'); }

  res.json(plant);
};

/** POST /plants (admin) */
exports.createPlant = async (req, res) => {
  const plant = await Plant.create(req.valid.body).catch(handleDuplicateCode);

  res.status(201).json(plant);
};

/** PATCH /plants/:id (admin) */
exports.updatePlant = async (req, res) => {
  const { id } = req.valid.params;

  // check plant found
  if (!(await Plant.findById(id))) { throw AppError.notFound('Plant'); }

  res.json(await Plant.update(id, req.valid.body).catch(handleDuplicateCode));
};

/** DELETE /plants/:id (admin) - refused with 409 RESOURCE_IN_USE while crops use the plant */
exports.deletePlant = async (req, res) => {
  // check plant deleted
  if (!(await Plant.delete(req.valid.params.id))) { throw AppError.notFound('Plant'); }

  res.status(204).end();
};
