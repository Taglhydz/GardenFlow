const express = require('express');
const router  = express.Router();
const plantController = require('../controllers/plantController');
const authMiddleware  = require('../middlewares/authMiddleware');

router.get	 ('/'	, authMiddleware, plantController.getAllPlants);
router.get	 ('/:id', authMiddleware, plantController.getPlantById);
router.post	 ('/'	, authMiddleware, plantController.createPlant );
router.put	 ('/:id', authMiddleware, plantController.updatePlant );
router.delete('/:id', authMiddleware, plantController.deletePlant );

module.exports = router;
