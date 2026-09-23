const Garden   = require('../models/gardenModel');
const Parcel   = require('../models/parcelModel');
const AppError = require('../utils/AppError');

// Ownership : a parcel belongs to the user who owns its garden.

/** GET /gardens/:gardenId/parcels */
exports.getParcelsByGarden = async (req, res) => {
  const { gardenId } = req.valid.params;

  // check garden found
  if (!(await Garden.findOwned(gardenId, req.user.id))) { throw AppError.notFound('Garden'); }

  res.json(await Parcel.findAllByGarden(gardenId));
};

/** POST /gardens/:gardenId/parcels */
exports.createParcel = async (req, res) => {
  const { gardenId } = req.valid.params;

  // check garden found
  if (!(await Garden.findOwned(gardenId, req.user.id))) { throw AppError.notFound('Garden'); }

  res.status(201).json(await Parcel.create(gardenId, req.valid.body));
};

/** GET /parcels/:id */
exports.getParcelById = async (req, res) => {
  const parcel = await Parcel.findOwned(req.valid.params.id, req.user.id);

  // check parcel found
  if (!parcel) { throw AppError.notFound('Parcel'); }

  res.json(parcel);
};

/** PATCH /parcels/:id */
exports.updateParcel = async (req, res) => {
  const { id } = req.valid.params;

  // check parcel found
  if (!(await Parcel.findOwned(id, req.user.id))) { throw AppError.notFound('Parcel'); }

  res.json(await Parcel.update(id, req.valid.body));
};

/** DELETE /parcels/:id - also deletes its crops */
exports.deleteParcel = async (req, res) => {
  // check parcel deleted
  if (!(await Parcel.deleteOwned(req.valid.params.id, req.user.id))) { throw AppError.notFound('Parcel'); }

  res.status(204).end();
};
