const Garden   = require('../models/gardenModel');
const Parcel   = require('../models/parcelModel');
const Zone     = require('../models/zoneModel');
const AppError = require('../utils/AppError');
const { polygonArea, isInside, overlap } = require('../utils/geometry');

// Ownership : a zone belongs to the user who owns its parcel's garden.
// Zone and parcel shapes are both relative to the parcel position, so they are compared directly.

/** A zone must be inside its parcel and must not overlap the other zones of the parcel. */
const checkShape = async (shape, parcel, zoneId = null) => {
  if (!isInside(shape, parcel.shape)) {
    throw AppError.badRequest('ZONE_OUTSIDE_PARCEL', 'The zone must be inside its parcel');
  }

  const others = (await Zone.findAllByParcel(parcel.id)).filter((z) => z.id !== zoneId);
  const overlapped = others.filter((z) => overlap(shape, z.shape));
  if (overlapped.length) {
    throw AppError.badRequest('ZONES_OVERLAP', `The zone overlaps: ${overlapped.map((z) => z.name).join(', ')}`);
  }
};

const areaOf = (shape) => Math.round(polygonArea(shape) * 100) / 100;

/** GET /gardens/:gardenId/zones - zones of all the parcels (one request for the garden plan) */
exports.getZonesByGarden = async (req, res) => {
  const { gardenId } = req.valid.params;

  // check garden found
  if (!(await Garden.findOwned(gardenId, req.user.id))) { throw AppError.notFound('Garden'); }

  res.json(await Zone.findAllByGarden(gardenId));
};

/** GET /parcels/:parcelId/zones */
exports.getZonesByParcel = async (req, res) => {
  const { parcelId } = req.valid.params;

  // check parcel found
  if (!(await Parcel.findOwned(parcelId, req.user.id))) { throw AppError.notFound('Parcel'); }

  res.json(await Zone.findAllByParcel(parcelId));
};

/** POST /parcels/:parcelId/zones */
exports.createZone = async (req, res) => {
  const parcel = await Parcel.findOwned(req.valid.params.parcelId, req.user.id);

  // check parcel found
  if (!parcel) { throw AppError.notFound('Parcel'); }

  const { name, shape } = req.valid.body;
  await checkShape(shape, parcel);

  res.status(201).json(await Zone.create(parcel.id, { name, shape, area_m2: areaOf(shape) }));
};

/** GET /zones/:id */
exports.getZoneById = async (req, res) => {
  const zone = await Zone.findOwned(req.valid.params.id, req.user.id);

  // check zone found
  if (!zone) { throw AppError.notFound('Zone'); }

  res.json(zone);
};

/** PATCH /zones/:id - name and / or shape */
exports.updateZone = async (req, res) => {
  const zone = await Zone.findOwned(req.valid.params.id, req.user.id);

  // check zone found
  if (!zone) { throw AppError.notFound('Zone'); }

  const data = { ...req.valid.body };
  if (data.shape) {
    const parcel = await Parcel.findOwned(zone.parcel_id, req.user.id);
    await checkShape(data.shape, parcel, zone.id);
    data.area_m2 = areaOf(data.shape);
  }

  res.json(await Zone.update(zone.id, data));
};

/** DELETE /zones/:id - its crops stay in the parcel, without zone */
exports.deleteZone = async (req, res) => {
  const zone = await Zone.findOwned(req.valid.params.id, req.user.id);

  // check zone found
  if (!zone) { throw AppError.notFound('Zone'); }

  await Zone.delete(zone.id);

  res.status(204).end();
};
