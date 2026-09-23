const Garden   = require('../models/gardenModel');
const Parcel   = require('../models/parcelModel');
const AppError = require('../utils/AppError');

// Ownership : a parcel belongs to the user who owns its garden.

/**
 * The area is computed from the dimensions (width x length) unless it is explicitly sent.
 * `current` is the stored parcel for an update.
 */
const withArea = (data, current = {}) => {
  if (data.area_m2 !== undefined || (data.width === undefined && data.length === undefined)) return data;

  const width  = data.width  ?? current.width  ?? 0;
  const length = data.length ?? current.length ?? 0;
  return { ...data, area_m2: width > 0 && length > 0 ? Math.round(width * length * 100) / 100 : null };
};

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

  res.status(201).json(await Parcel.create(gardenId, withArea(req.valid.body)));
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

  const parcel = await Parcel.findOwned(id, req.user.id);

  // check parcel found
  if (!parcel) { throw AppError.notFound('Parcel'); }

  res.json(await Parcel.update(id, withArea(req.valid.body, parcel)));
};

/** DELETE /parcels/:id - also deletes its crops */
exports.deleteParcel = async (req, res) => {
  // check parcel deleted
  if (!(await Parcel.deleteOwned(req.valid.params.id, req.user.id))) { throw AppError.notFound('Parcel'); }

  res.status(204).end();
};
