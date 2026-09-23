const express = require('express');
const router  = express.Router();
const userController = require('../controllers/userController');
const validate       = require('../middlewares/validate');
const { authenticate, requireAdmin } = require('../middlewares/authMiddleware');
const { idParam } = require('../validators/common');
const { updateMeSchema, changePasswordSchema, adminUpdateUserSchema } = require('../validators/userValidators');

router.use(authenticate);

// current user (declared before /:id so that "me" is not read as an id)
router.get   ('/me'         , userController.getMe);
router.patch ('/me'         , validate({ body: updateMeSchema       }), userController.updateMe      );
router.patch ('/me/password', validate({ body: changePasswordSchema }), userController.changePassword);
router.delete('/me'         , userController.deleteMe);

// admin only
router.get   ('/'   , requireAdmin, userController.getAllUsers);
router.get   ('/:id', requireAdmin, validate({ params: idParam() }), userController.getUserById);
router.patch ('/:id', requireAdmin, validate({ params: idParam(), body: adminUpdateUserSchema }), userController.updateUserById);
router.delete('/:id', requireAdmin, validate({ params: idParam() }), userController.deleteUserById);

module.exports = router;
