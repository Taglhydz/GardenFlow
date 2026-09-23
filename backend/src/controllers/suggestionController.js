const Parcel           = require('../models/parcelModel');
const Zone             = require('../models/zoneModel');
const Crop             = require('../models/cropModel');
const Plant            = require('../models/plantModel');
const PlantAssociation = require('../models/plantAssociationModel');
const AppError         = require('../utils/AppError');
const { suggestPlants } = require('../services/suggestionEngine');

/** Loads the garden data and runs the engine. Suggestions are computed on each request, nothing is stored. */
const suggest = async ({ parcel, zone = null, month }) => {
  const [parcels, crops, plants, associations] = await Promise.all([
    Parcel.findAllByGarden(parcel.garden_id),
    Crop.findAllByGarden(parcel.garden_id),
    Plant.findAll(),
    PlantAssociation.findAll(),
  ]);

  return suggestPlants({
    parcel,
    zone,
    parcels,
    crops,
    plants,
    associations,
    month,
    today: new Date().toISOString().slice(0, 10),
  });
};

const monthOf = (req) => req.valid.query.month ?? new Date().getMonth() + 1;

/**
 * GET /parcels/:id/suggestions?month=5
 * Plants to sow or plant in the whole parcel for the month (current month by default), best first.
 */
exports.getParcelSuggestions = async (req, res) => {
  const parcel = await Parcel.findOwned(req.valid.params.id, req.user.id);

  // check parcel found
  if (!parcel) { throw AppError.notFound('Parcel'); }

  const month = monthOf(req);
  res.json({ parcel_id: parcel.id, month, suggestions: await suggest({ parcel, month }) });
};

/**
 * GET /zones/:id/suggestions?month=5
 * Same for a zone : companions in the zone count more than in the rest of the parcel,
 * and the crop rotation uses the history of the zone.
 */
exports.getZoneSuggestions = async (req, res) => {
  const zone = await Zone.findOwned(req.valid.params.id, req.user.id);

  // check zone found
  if (!zone) { throw AppError.notFound('Zone'); }

  const parcel = await Parcel.findOwned(zone.parcel_id, req.user.id);
  const month = monthOf(req);
  res.json({ parcel_id: parcel.id, zone_id: zone.id, month, suggestions: await suggest({ parcel, zone, month }) });
};
