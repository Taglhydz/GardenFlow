const express = require('express');
const router  = express.Router();
const userController       = require('../controllers/userController');
const plantColorController = require('../controllers/plantColorController');
const validate       = require('../middlewares/validate');
const { authenticate, requireAdmin } = require('../middlewares/authMiddleware');
const { idParam } = require('../validators/common');
const { uploadPhoto } = require('../utils/photoStorage');
const {
  updateMeSchema, changeEmailSchema, changePasswordSchema, adminUpdateUserSchema, plantColorSchema,
} = require('../validators/userValidators');

router.use(authenticate);

// current user (declared before /:id so that "me" is not read as an id)
router.get   ('/me'         , userController.getMe);
router.patch ('/me'         , validate({ body: updateMeSchema       }), userController.updateMe      );
router.patch ('/me/password', validate({ body: changePasswordSchema }), userController.changePassword);
router.patch ('/me/email'   , validate({ body: changeEmailSchema    }), userController.changeEmail   );
router.delete('/me/email'   , userController.cancelEmailChange);
router.delete('/me'         , userController.deleteMe);

// picture and level of the current user
router.post  ('/me/photo'   , uploadPhoto, userController.uploadMyPhoto);
router.delete('/me/photo'   , userController.deleteMyPhoto);
router.get   ('/me/level'   , userController.getMyLevel);

// colors chosen for the plants on the plans
router.get   ('/me/plant-colors'          , plantColorController.getMyPlantColors);
router.put   ('/me/plant-colors/:plantId' , validate({ params: idParam('plantId'), body: plantColorSchema }), plantColorController.setMyPlantColor);
router.delete('/me/plant-colors/:plantId' , validate({ params: idParam('plantId') }), plantColorController.deleteMyPlantColor);

// admin only
router.get   ('/'   , requireAdmin, userController.getAllUsers);
router.get   ('/:id', requireAdmin, validate({ params: idParam() }), userController.getUserById);
router.patch ('/:id', requireAdmin, validate({ params: idParam(), body: adminUpdateUserSchema }), userController.updateUserById);
router.delete('/:id', requireAdmin, validate({ params: idParam() }), userController.deleteUserById);

module.exports = router;
