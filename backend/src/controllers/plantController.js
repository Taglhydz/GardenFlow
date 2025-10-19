const Plant = require('../models/plantModel');

exports.getAllPlants = async (req, res) => {
  try {
    const plants = await Plant.getAll();

    res.json(plants);

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.getPlantById = async (req, res) => {
  try {
    const { id } = req.params;
    const plant = await Plant.getById(id);

	// check plant found
    if (!plant) {  return res.status(404).json({ message: 'Plant not found' }); }
	
    res.json(plant);

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.createPlant = async (req, res) => {
  try {
    const { name, type, description, sow_start_month, sow_end_month, harvest_start_month, harvest_end_month, sunlight_need, water_need, preferred_soil, spacing_cm } = req.body;
    
	// check required fields
	if (!name) { return res.status(400).json({ message: 'Missing required field: name' }); }

    const newPlant = await Plant.create({ name, type, description, sow_start_month, sow_end_month, harvest_start_month, harvest_end_month, sunlight_need, water_need, preferred_soil, spacing_cm });
    
	res.status(201).json(newPlant);

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.updatePlant = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, type, description, sow_start_month, sow_end_month, harvest_start_month, harvest_end_month, sunlight_need, water_need, preferred_soil, spacing_cm } = req.body;
    const result = await Plant.update(id, { name, type, description, sow_start_month, sow_end_month, harvest_start_month, harvest_end_month, sunlight_need, water_need, preferred_soil, spacing_cm });
    
	// check plant deleted or not found
	if (result.affectedRows === 0) { return res.status(404).json({ message: 'Plant not found or not updated' }); }

    res.json({ message: 'Plant updated' });

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.deletePlant = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await Plant.softDelete(id);

	// check plant deleted or not found
    if (result.affectedRows === 0) { return res.status(404).json({ message: 'Plant not found or already deleted' }); }

    res.json({ message: 'Plant deleted (soft)' });

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};
