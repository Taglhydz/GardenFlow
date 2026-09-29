const PlantColor = require('../models/plantColorModel');
const Plant      = require('../models/plantModel');
const AppError   = require('../utils/AppError');

// Colors chosen by the current user for the plants of his plans (the others keep their automatic color).

/** GET /users/me/plant-colors */
exports.getMyPlantColors = async (req, res) => {
  res.json(await PlantColor.findByUser(req.user.id));
};

/** PUT /users/me/plant-colors/:plantId { hue } */
exports.setMyPlantColor = async (req, res) => {
  const { plantId } = req.valid.params;

  // check plant found
  if (!(await Plant.findById(plantId))) { throw AppError.notFound('Plant'); }

  res.json(await PlantColor.set(req.user.id, plantId, req.valid.body.hue));
};

/** DELETE /users/me/plant-colors/:plantId - back to the automatic color */
exports.deleteMyPlantColor = async (req, res) => {
  // check color deleted
  if (!(await PlantColor.delete(req.user.id, req.valid.params.plantId))) { throw AppError.notFound('Plant color'); }

  res.status(204).end();
};
