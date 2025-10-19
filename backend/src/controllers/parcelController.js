const Parcel = require('../models/parcelModel');

exports.getAllParcels = async (req, res) => {
  try {
    const parcels = await Parcel.getAll();

    res.json(parcels);

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.getParcelById = async (req, res) => {
  try {
    const { id } = req.params;
    const parcel = await Parcel.getById(id);

	// check parcel found
    if (!parcel) { return res.status(404).json({ message: 'Parcel not found' }); }

    res.json(parcel);

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.createParcel = async (req, res) => {
  try {
    const { garden_id, name, area_m2, pos_x, pos_y, width, length, soil_type, sunlight, moisture } = req.body;

	// check required fields
    if (!garden_id || !name) { return res.status(400).json({ message: 'Missing required fields' }); }

    const newParcel = await Parcel.create({ garden_id, name, area_m2, pos_x, pos_y, width, length, soil_type, sunlight, moisture });

    res.status(201).json(newParcel);

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.updateParcel = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, area_m2, pos_x, pos_y, width, length, soil_type, sunlight, moisture } = req.body;
    const result = await Parcel.update(id, { name, area_m2, pos_x, pos_y, width, length, soil_type, sunlight, moisture });

	// check parcel updated or found
    if (result.affectedRows === 0) { return res.status(404).json({ message: 'Parcel not found or not updated' }); }

    res.json({ message: 'Parcel updated' });
	
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.deleteParcel = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await Parcel.softDelete(id);

	// check parcel deleted or found
    if (result.affectedRows === 0) { return res.status(404).json({ message: 'Parcel not found or already deleted' }); }

    res.json({ message: 'Parcel deleted (soft)' });

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.getParcelsByGardenId = async (req, res) => {
  try {
    const { garden_id } = req.params;
    const parcels = await Parcel.getByGardenId(garden_id);

    res.json(parcels);
	
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};
