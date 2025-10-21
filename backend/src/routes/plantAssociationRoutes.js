const express = require('express');
const router  = express.Router();
const plantAssociationController = require('../controllers/plantAssociationController');
const authMiddleware 			 = require('../middlewares/authMiddleware');

router.get	 ('/'	, authMiddleware, plantAssociationController.getAllPlantAssociations);
router.get	 ('/:id', authMiddleware, plantAssociationController.getPlantAssociationById);
router.post	 ('/'	, authMiddleware, plantAssociationController.createPlantAssociation );
router.put	 ('/:id', authMiddleware, plantAssociationController.updatePlantAssociation );
router.delete('/:id', authMiddleware, plantAssociationController.deletePlantAssociation );

module.exports = router;
