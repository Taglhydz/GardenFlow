const express = require('express');
const router = express.Router();

const authRoutes 			 = require('./authRoutes'			 );
const userRoutes 			 = require('./userRoutes'			 );
const gardenRoutes 			 = require('./gardenRoutes'			 );
const parcelRoutes 			 = require('./parcelRoutes'			 );
const plantRoutes 			 = require('./plantRoutes'			 );
const cropRoutes 			 = require('./cropRoutes'			 );
const plantAssociationRoutes = require('./plantAssociationRoutes');
const zoneRoutes 			 = require('./zoneRoutes'			 );

router.get('/health', (req, res) => res.json({ status: 'ok' }));

router.use('/auth'				, authRoutes			);
router.use('/users'				, userRoutes			);
router.use('/gardens'			, gardenRoutes			);
router.use('/parcels'			, parcelRoutes			);
router.use('/zones'				, zoneRoutes				);
router.use('/plants'			, plantRoutes			);
router.use('/crops'			 	, cropRoutes			);
router.use('/plant-associations', plantAssociationRoutes);

module.exports = router;
