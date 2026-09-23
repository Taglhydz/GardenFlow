const express = require('express');
const router  = express.Router();
const plantAssociationController = require('../controllers/plantAssociationController');
const validate                   = require('../middlewares/validate');
const { authenticate, requireAdmin } = require('../middlewares/authMiddleware');
const { idParam } = require('../validators/common');
const {
  createAssociationSchema, updateAssociationSchema, listAssociationsQuerySchema,
} = require('../validators/plantValidators');

router.use(authenticate);

// read : every logged in user
router.get('/'   , validate({ query: listAssociationsQuerySchema }), plantAssociationController.getAllPlantAssociations);
router.get('/:id', validate({ params: idParam() }), plantAssociationController.getPlantAssociationById);

// write : admin only
router.post  ('/'   , requireAdmin, validate({ body: createAssociationSchema }), plantAssociationController.createPlantAssociation);
router.patch ('/:id', requireAdmin, validate({ params: idParam(), body: updateAssociationSchema }), plantAssociationController.updatePlantAssociation);
router.delete('/:id', requireAdmin, validate({ params: idParam() }), plantAssociationController.deletePlantAssociation);

module.exports = router;
