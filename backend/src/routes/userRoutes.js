const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const authMiddleware = require('../middlewares/authMiddleware');

router.get	 ('/'	, authMiddleware, userController.getAllUsers);
router.get	 ('/:id', authMiddleware, userController.getUserById);
router.post	 ('/'	, authMiddleware, userController.createUser	);
router.put	 ('/:id', authMiddleware, userController.updateUser	);
router.delete('/:id', authMiddleware, userController.deleteUser	);

module.exports = router;
