const Garden   = require('../models/gardenModel');
const Parcel   = require('../models/parcelModel');
const Crop     = require('../models/cropModel');
const Zone     = require('../models/zoneModel');
const AppError = require('../utils/AppError');
const { cropDatesIssues } = require('../validators/gardenValidators');

// Ownership : a crop belongs to the user who owns its parcel's garden.
// An unknown plant_id is rejected by the foreign key (400 INVALID_REFERENCE).

const checkDates = (crop) => {
  const issues = cropDatesIssues(crop);
  if (issues.length) { throw AppError.badRequest('VALIDATION_ERROR', 'Invalid crop dates', issues); }
};

/** The zone of a crop must belong to the crop's parcel (null = the whole parcel). */
const checkZone = async (zoneId, parcelId, userId) => {
  if (zoneId == null) return;
  const zone = await Zone.findOwned(zoneId, userId);
  if (!zone || zone.parcel_id !== parcelId) {
    throw AppError.badRequest('INVALID_ZONE', 'The zone does not belong to the parcel of the crop');
  }
};

/** GET /gardens/:gardenId/crops - crops of all the parcels of the garden (one request for the garden plan) */
exports.getCropsByGarden = async (req, res) => {
  const { gardenId } = req.valid.params;

  // check garden found
  if (!(await Garden.findOwned(gardenId, req.user.id))) { throw AppError.notFound('Garden'); }

  res.json(await Crop.findAllByGarden(gardenId));
};

/** GET /parcels/:parcelId/crops */
exports.getCropsByParcel = async (req, res) => {
  const { parcelId } = req.valid.params;

  // check parcel found
  if (!(await Parcel.findOwned(parcelId, req.user.id))) { throw AppError.notFound('Parcel'); }

  res.json(await Crop.findAllByParcel(parcelId));
};

/** POST /parcels/:parcelId/crops */
exports.createCrop = async (req, res) => {
  const { parcelId } = req.valid.params;

  // check parcel found
  if (!(await Parcel.findOwned(parcelId, req.user.id))) { throw AppError.notFound('Parcel'); }

  checkDates(req.valid.body);
  await checkZone(req.valid.body.zone_id, parcelId, req.user.id);

  res.status(201).json(await Crop.create(parcelId, req.valid.body));
};

/** GET /crops/:id */
exports.getCropById = async (req, res) => {
  const crop = await Crop.findOwned(req.valid.params.id, req.user.id);

  // check crop found
  if (!crop) { throw AppError.notFound('Crop'); }

  res.json(crop);
};

/** PATCH /crops/:id */
exports.updateCrop = async (req, res) => {
  const { id } = req.valid.params;
  const crop = await Crop.findOwned(id, req.user.id);

  // check crop found
  if (!crop) { throw AppError.notFound('Crop'); }

  // the dates are checked on the final state : stored values + modified values
  checkDates({ ...crop, ...req.valid.body });
  await checkZone(req.valid.body.zone_id, crop.parcel_id, req.user.id);

  res.json(await Crop.update(id, req.valid.body));
};

/** DELETE /crops/:id */
exports.deleteCrop = async (req, res) => {
  // check crop deleted
  if (!(await Crop.deleteOwned(req.valid.params.id, req.user.id))) { throw AppError.notFound('Crop'); }

  res.status(204).end();
};
