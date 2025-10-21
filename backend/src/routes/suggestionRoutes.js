const express = require('express');
const router  = express.Router();
const suggestionController = require('../controllers/suggestionController');
const authMiddleware 	   = require('../middlewares/authMiddleware');

router.get	 ('/'	, authMiddleware, suggestionController.getAllSuggestions);
router.get	 ('/:id', authMiddleware, suggestionController.getSuggestionById);
router.post	 ('/'	, authMiddleware, suggestionController.createSuggestion );
router.put	 ('/:id', authMiddleware, suggestionController.updateSuggestion );
router.delete('/:id', authMiddleware, suggestionController.deleteSuggestion );

module.exports = router;
