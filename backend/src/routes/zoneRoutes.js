const express = require('express');
const router  = express.Router();
const zoneController       = require('../controllers/zoneController');
const suggestionController = require('../controllers/suggestionController');
const validate             = require('../middlewares/validate');
const { authenticate } = require('../middlewares/authMiddleware');
const { idParam } = require('../validators/common');
const { updateZoneSchema, suggestionsQuerySchema } = require('../validators/gardenValidators');

// list / create zones : see parcelRoutes (/parcels/:parcelId/zones)
router.use(authenticate);

router.get   ('/:id', validate({ params: idParam() }), zoneController.getZoneById);
router.patch ('/:id', validate({ params: idParam(), body: updateZoneSchema }), zoneController.updateZone);
router.delete('/:id', validate({ params: idParam() }), zoneController.deleteZone);

// computed suggestions for a zone
router.get('/:id/suggestions', validate({ params: idParam(), query: suggestionsQuerySchema }), suggestionController.getZoneSuggestions);

module.exports = router;
