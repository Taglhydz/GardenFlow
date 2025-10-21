const express = require('express');
const router = express.Router();

const authRoutes 			 = require('./authRoutes'			 );
const userRoutes 			 = require('./userRoutes'			 );
const gardenRoutes 			 = require('./gardenRoutes'			 );
const parcelRoutes 			 = require('./parcelRoutes'			 );
const plantRoutes 			 = require('./plantRoutes'			 );
const cropRoutes 			 = require('./cropRoutes'			 );
const plantAssociationRoutes = require('./plantAssociationRoutes');
const suggestionRoutes 		 = require('./suggestionRoutes'		 );

router.use('/auth'				, authRoutes			);
router.use('/users'				, userRoutes			);
router.use('/gardens'			, gardenRoutes			);
router.use('/parcels'			, parcelRoutes			);
router.use('/plants'			, plantRoutes			);
router.use('/crops'			 	, cropRoutes			);
router.use('/plant-associations', plantAssociationRoutes);
router.use('/suggestions'		, suggestionRoutes		);

module.exports = router;
