const express = require('express');
const router  = express.Router();
const gardenController = require('../controllers/gardenController');
const parcelController = require('../controllers/parcelController');
const cropController   = require('../controllers/cropController');
const validate         = require('../middlewares/validate');
const { authenticate } = require('../middlewares/authMiddleware');
const { idParam } = require('../validators/common');
const { createGardenSchema, updateGardenSchema, createParcelSchema } = require('../validators/gardenValidators');

router.use(authenticate);

router.get   ('/'   , gardenController.getMyGardens);
router.post  ('/'   , validate({ body: createGardenSchema }), gardenController.createGarden);
router.get   ('/:id', validate({ params: idParam() }), gardenController.getGardenById);
router.patch ('/:id', validate({ params: idParam(), body: updateGardenSchema }), gardenController.updateGarden);
router.delete('/:id', validate({ params: idParam() }), gardenController.deleteGarden);

// parcels of a garden
router.get ('/:gardenId/parcels', validate({ params: idParam('gardenId') }), parcelController.getParcelsByGarden);
router.post('/:gardenId/parcels', validate({ params: idParam('gardenId'), body: createParcelSchema }), parcelController.createParcel);

// crops of all the parcels of a garden
router.get('/:gardenId/crops', validate({ params: idParam('gardenId') }), cropController.getCropsByGarden);

module.exports = router;
