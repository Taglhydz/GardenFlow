const Garden = require('../models/gardenModel');

exports.getAllGardens = async (req, res) => {
  try {
    const gardens = await Garden.getAll();

    res.json(gardens);

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.getGardenById = async (req, res) => {
  try {
    const { id } = req.params;
    const garden = await Garden.getById(id);

	// check garden found
    if (!garden) { return res.status(404).json({ message: 'Garden not found' }); }

    res.json(garden);

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.createGarden = async (req, res) => {
  try {
    const { user_id, name, location, description } = req.body;

	// check required fields
    if (!user_id || !name) { return res.status(400).json({ message: 'Missing required fields' }); }

    const newGarden = await Garden.create({ user_id, name, location, description });

    res.status(201).json(newGarden);

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.updateGarden = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, location, description } = req.body;
    const result = await Garden.update(id, { name, location, description });

	// check garden deleted or not found
    if (result.affectedRows === 0) { return res.status(404).json({ message: 'Garden not found or not updated' }); }

    res.json({ message: 'Garden updated' });

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.deleteGarden = async (req, res) => {
  try {
    const { id } = req.params;
    const result = await Garden.softDelete(id);

	// check garden deleted or not found
    if (result.affectedRows === 0) { return res.status(404).json({ message: 'Garden not found or already deleted' }); }

    res.json({ message: 'Garden deleted (soft)' });

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.getGardensByUserId = async (req, res) => {
  try {
    const { user_id } = req.params;
    const gardens = await Garden.getByUserId(user_id);

    res.json(gardens);
	
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};
