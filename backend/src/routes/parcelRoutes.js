const express = require('express');
const router  = express.Router();
const parcelController = require('../controllers/parcelController');
const authMiddleware   = require('../middlewares/authMiddleware');

router.get	 ('/'				  , authMiddleware, parcelController.getAllParcels		 );
router.get	 ('/:id'			  , authMiddleware, parcelController.getParcelById		 );
router.get	 ('/garden/:garden_id', authMiddleware, parcelController.getParcelsByGardenId);
router.post	 ('/'				  , authMiddleware, parcelController.createParcel		 );
router.put	 ('/:id'			  , authMiddleware, parcelController.updateParcel		 );
router.delete('/:id'			  , authMiddleware, parcelController.deleteParcel		 );

module.exports = router;
