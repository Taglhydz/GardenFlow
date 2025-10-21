const express = require('express');
const router  = express.Router();
const cropController = require('../controllers/cropController');
const authMiddleware = require('../middlewares/authMiddleware');

router.get	 ('/'	, authMiddleware, cropController.getAllCrops);
router.get	 ('/:id', authMiddleware, cropController.getCropById);
router.post	 ('/'	, authMiddleware, cropController.createCrop );
router.put	 ('/:id', authMiddleware, cropController.updateCrop );
router.delete('/:id', authMiddleware, cropController.deleteCrop );

module.exports = router;
