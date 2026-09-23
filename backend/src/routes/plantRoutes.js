const express = require('express');
const router  = express.Router();
const plantController = require('../controllers/plantController');
const validate        = require('../middlewares/validate');
const { authenticate, requireAdmin } = require('../middlewares/authMiddleware');
const { idParam } = require('../validators/common');
const { createPlantSchema, updatePlantSchema, listPlantsQuerySchema } = require('../validators/plantValidators');

router.use(authenticate);

// read : every logged in user
router.get('/'   , validate({ query: listPlantsQuerySchema }), plantController.getAllPlants);
router.get('/:id', validate({ params: idParam() }), plantController.getPlantById);

// write : admin only
router.post  ('/'   , requireAdmin, validate({ body: createPlantSchema }), plantController.createPlant);
router.patch ('/:id', requireAdmin, validate({ params: idParam(), body: updatePlantSchema }), plantController.updatePlant);
router.delete('/:id', requireAdmin, validate({ params: idParam() }), plantController.deletePlant);

module.exports = router;
