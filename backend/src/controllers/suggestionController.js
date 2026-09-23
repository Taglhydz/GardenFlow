const Parcel           = require('../models/parcelModel');
const Crop             = require('../models/cropModel');
const Plant            = require('../models/plantModel');
const PlantAssociation = require('../models/plantAssociationModel');
const AppError         = require('../utils/AppError');
const { suggestPlants } = require('../services/suggestionEngine');

/**
 * GET /parcels/:id/suggestions?month=5
 * Plants to sow or plant in this parcel for the month (current month by default), best first.
 * Suggestions are computed on each request, nothing is stored.
 */
exports.getParcelSuggestions = async (req, res) => {
  const parcel = await Parcel.findOwned(req.valid.params.id, req.user.id);

  // check parcel found
  if (!parcel) { throw AppError.notFound('Parcel'); }

  const month = req.valid.query.month ?? new Date().getMonth() + 1;

  const [parcels, crops, plants, associations] = await Promise.all([
    Parcel.findAllByGarden(parcel.garden_id),
    Crop.findAllByGarden(parcel.garden_id),
    Plant.findAll(),
    PlantAssociation.findAll(),
  ]);

  const suggestions = suggestPlants({
    parcel,
    parcels,
    crops,
    plants,
    associations,
    month,
    today: new Date().toISOString().slice(0, 10),
  });

  res.json({ parcel_id: parcel.id, month, suggestions });
};
