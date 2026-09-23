const Garden   = require('../models/gardenModel');
const AppError = require('../utils/AppError');

// All routes only access the gardens of the logged in user (req.user.id).
// A garden of another user answers 404, so we don't reveal that it exists.

/** GET /gardens - my gardens */
exports.getMyGardens = async (req, res) => {
  res.json(await Garden.findAllByUser(req.user.id));
};

/** GET /gardens/:id */
exports.getGardenById = async (req, res) => {
  const garden = await Garden.findOwned(req.valid.params.id, req.user.id);

  // check garden found
  if (!garden) { throw AppError.notFound('Garden'); }

  res.json(garden);
};

/** POST /gardens - the owner is the logged in user, never a user_id from the body */
exports.createGarden = async (req, res) => {
  res.status(201).json(await Garden.create(req.user.id, req.valid.body));
};

/** PATCH /gardens/:id */
exports.updateGarden = async (req, res) => {
  const { id } = req.valid.params;

  // check garden found
  if (!(await Garden.findOwned(id, req.user.id))) { throw AppError.notFound('Garden'); }

  res.json(await Garden.update(id, req.user.id, req.valid.body));
};

/** DELETE /gardens/:id - also deletes its parcels and crops */
exports.deleteGarden = async (req, res) => {
  // check garden deleted
  if (!(await Garden.delete(req.valid.params.id, req.user.id))) { throw AppError.notFound('Garden'); }

  res.status(204).end();
};
