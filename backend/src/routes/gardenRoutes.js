const express = require('express');
const router  = express.Router();
const gardenController = require('../controllers/gardenController');
const authMiddleware   = require('../middlewares/authMiddleware');

router.get	 ('/'		  	  , authMiddleware, gardenController.getAllGardens	   );
router.get	 ('/:id'		  , authMiddleware, gardenController.getGardenById	   );
router.get	 ('/user/:user_id', authMiddleware, gardenController.getGardensByUserId);
router.post	 ('/'			  , authMiddleware, gardenController.createGarden	   );
router.put	 ('/:id'		  , authMiddleware, gardenController.updateGarden	   );
router.delete('/:id'		  , authMiddleware, gardenController.deleteGarden	   );

module.exports = router;
