const express = require('express');
const router  = express.Router();
const parcelController = require('../controllers/parcelController');
const cropController   = require('../controllers/cropController');
const validate         = require('../middlewares/validate');
const { authenticate } = require('../middlewares/authMiddleware');
const { idParam } = require('../validators/common');
const { updateParcelSchema, createCropSchema } = require('../validators/gardenValidators');

// list / create parcels : see gardenRoutes (/gardens/:gardenId/parcels)
router.use(authenticate);

router.get   ('/:id', validate({ params: idParam() }), parcelController.getParcelById);
router.patch ('/:id', validate({ params: idParam(), body: updateParcelSchema }), parcelController.updateParcel);
router.delete('/:id', validate({ params: idParam() }), parcelController.deleteParcel);

// crops of a parcel
router.get ('/:parcelId/crops', validate({ params: idParam('parcelId') }), cropController.getCropsByParcel);
router.post('/:parcelId/crops', validate({ params: idParam('parcelId'), body: createCropSchema }), cropController.createCrop);

module.exports = router;
