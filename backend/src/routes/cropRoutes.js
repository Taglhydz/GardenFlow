const express = require('express');
const router  = express.Router();
const cropController   = require('../controllers/cropController');
const validate         = require('../middlewares/validate');
const { authenticate } = require('../middlewares/authMiddleware');
const { idParam } = require('../validators/common');
const { updateCropSchema } = require('../validators/gardenValidators');

// list / create crops : see parcelRoutes (/parcels/:parcelId/crops)
router.use(authenticate);

router.get   ('/:id', validate({ params: idParam() }), cropController.getCropById);
router.patch ('/:id', validate({ params: idParam(), body: updateCropSchema }), cropController.updateCrop);
router.delete('/:id', validate({ params: idParam() }), cropController.deleteCrop);

module.exports = router;
