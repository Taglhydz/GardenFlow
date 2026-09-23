const Garden   = require('../models/gardenModel');
const Parcel   = require('../models/parcelModel');
const Zone     = require('../models/zoneModel');
const AppError = require('../utils/AppError');
const { polygonArea, isInside } = require('../utils/geometry');

// Ownership : a parcel belongs to the user who owns its garden.

/** The area is always computed from the shape. */
const withArea = (data) => (data.shape === undefined
  ? data
  : { ...data, area_m2: Math.round(polygonArea(data.shape) * 100) / 100 });

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

/**
 * PATCH /parcels/:id
 * Moving the parcel (pos_x / pos_y) moves its zones with it (their shape is relative to the parcel).
 * A new shape is refused if a zone would no longer be inside the parcel.
 */
exports.updateParcel = async (req, res) => {
  const { id } = req.valid.params;
  const body = req.valid.body;

  // check parcel found
  if (!(await Parcel.findOwned(id, req.user.id))) { throw AppError.notFound('Parcel'); }

  if (body.shape) {
    const outside = (await Zone.findAllByParcel(id)).filter((zone) => !isInside(zone.shape, body.shape));
    if (outside.length) {
      throw AppError.conflict('ZONES_OUTSIDE_PARCEL', `Zones would be outside the parcel: ${outside.map((z) => z.name).join(', ')}`);
    }
  }

  res.json(await Parcel.update(id, withArea(body)));
};

/** DELETE /parcels/:id - also deletes its zones and crops */
exports.deleteParcel = async (req, res) => {
  // check parcel deleted
  if (!(await Parcel.deleteOwned(req.valid.params.id, req.user.id))) { throw AppError.notFound('Parcel'); }

  res.status(204).end();
};
