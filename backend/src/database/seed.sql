-- =========================
-- GardenFlow reference data
-- =========================
-- Plant catalog, plant calendars and plant associations. Run after schema.sql
-- (`npm run db:reset` runs both).
-- Texts are in French ; the Flutter app translates them with the plant `code`
-- (plants.<code>.name / plants.<code>.description in assets/translations/*.json).
--
-- Months are indicative for a temperate climate (France).

INSERT INTO plant
  (code, name, type, family, description, days_to_maturity, sunlight_need, water_need, preferred_soil, spacing_cm)
VALUES
  -- Vegetables
  ('tomato',     'Tomate',            'vegetable', 'solanaceae',     'Légume-fruit d''été gourmand en chaleur. Semer sous abri, repiquer après les dernières gelées.',          70, 'high',   'medium', 'humus',    50),
  ('carrot',     'Carotte',           'vegetable', 'apiaceae',       'Racine à semer en place dans une terre légère et sans cailloux.',                                          90, 'high',   'medium', 'sandy',     5),
  ('lettuce',    'Laitue',            'vegetable', 'asteraceae',     'Salade à croissance rapide, à semer en échelonnant pour récolter toute la saison.',                        60, 'medium', 'medium', 'loamy',    25),
  ('radish',     'Radis',             'vegetable', 'brassicaceae',   'Récolte en 4 semaines environ, idéal pour débuter.',                                                       30, 'medium', 'medium', 'loamy',     5),
  ('green_bean', 'Haricot vert',      'vegetable', 'fabaceae',       'Légumineuse frileuse à semer en place quand la terre est réchauffée. Enrichit le sol en azote.',           60, 'high',   'medium', 'loamy',    10),
  ('pea',        'Petit pois',        'vegetable', 'fabaceae',       'Légumineuse de saison fraîche, à semer tôt au printemps. Enrichit le sol en azote.',                       90, 'medium', 'medium', 'loamy',     5),
  ('zucchini',   'Courgette',         'vegetable', 'cucurbitaceae',  'Plante vigoureuse et très productive, gourmande en eau et en matière organique.',                           60, 'high',   'high',   'humus',   100),
  ('cucumber',   'Concombre',         'vegetable', 'cucurbitaceae',  'Aime la chaleur et un arrosage régulier, peut être palissé.',                                              70, 'high',   'high',   'humus',    60),
  ('potato',     'Pomme de terre',    'vegetable', 'solanaceae',     'Tubercule à planter au printemps, à butter au cours de la croissance.',                                   100, 'high',   'medium', 'loamy',    35),
  ('onion',      'Oignon',            'vegetable', 'amaryllidaceae', 'Bulbe à semer ou planter en bulbilles, n''aime pas l''excès d''eau.',                                    120, 'high',   'low',    'loamy',    10),
  ('garlic',     'Ail',               'vegetable', 'amaryllidaceae', 'Caïeux à planter en automne ou en fin d''hiver dans un sol bien drainé.',                                 150, 'high',   'low',    'sandy',    10),
  ('leek',       'Poireau',           'vegetable', 'amaryllidaceae', 'Légume d''hiver très rustique, à repiquer en été.',                                                       120, 'medium', 'medium', 'loamy',    15),
  ('spinach',    'Épinard',           'vegetable', 'amaranthaceae',  'Légume-feuille de saison fraîche qui monte vite en graines par temps chaud.',                              45, 'medium', 'high',   'humus',    15),
  ('cabbage',    'Chou',              'vegetable', 'brassicaceae',   'Légume exigeant en nutriments, apprécie les sols lourds et frais.',                                       100, 'medium', 'high',   'clay',     50),
  ('beetroot',   'Betterave',         'vegetable', 'amaranthaceae',  'Racine facile à cultiver, se conserve bien.',                                                              80, 'high',   'medium', 'loamy',    10),
  ('pepper',     'Poivron',           'vegetable', 'solanaceae',     'Très frileux, à semer au chaud en fin d''hiver.',                                                          80, 'high',   'medium', 'humus',    45),
  ('eggplant',   'Aubergine',         'vegetable', 'solanaceae',     'Demande beaucoup de chaleur et de soleil pour bien produire.',                                             90, 'high',   'medium', 'humus',    60),
  ('squash',     'Courge',            'vegetable', 'cucurbitaceae',  'Plante coureuse qui prend beaucoup de place, récolte avant les gelées.',                                  110, 'high',   'high',   'humus',   150),
  ('corn',       'Maïs doux',         'vegetable', 'poaceae',        'À semer en bloc plutôt qu''en ligne pour une bonne pollinisation.',                                        90, 'high',   'medium', 'loamy',    30),
  ('celery',     'Céleri',            'vegetable', 'apiaceae',       'Aime les sols riches et frais, arrosage régulier indispensable.',                                         120, 'medium', 'high',   'humus',    40),
  ('fennel',     'Fenouil',           'vegetable', 'apiaceae',       'Bulbe à semer en été, freine la croissance de nombreuses plantes voisines.',                               90, 'high',   'medium', 'loamy',    30),
  ('turnip',     'Navet',             'vegetable', 'brassicaceae',   'Racine rapide, surtout cultivée en fin d''été pour l''automne.',                                            60, 'medium', 'medium', 'loamy',    10),
  -- Fruits
  ('strawberry', 'Fraisier',          'fruit',     'rosaceae',       'Vivace à planter en fin d''été ou au printemps, se multiplie par stolons.',                              NULL, 'high',   'medium', 'humus',    30),
  -- Herbs
  ('basil',      'Basilic',           'herb',      'lamiaceae',      'Aromatique frileuse, à semer au chaud et à pincer régulièrement.',                                         60, 'high',   'medium', 'humus',    25),
  ('parsley',    'Persil',            'herb',      'apiaceae',       'Bisannuelle à la germination lente.',                                                                      80, 'medium', 'medium', 'loamy',    15),
  ('chives',     'Ciboulette',        'herb',      'amaryllidaceae', 'Vivace facile, repousse après chaque coupe.',                                                              60, 'medium', 'medium', 'loamy',    20),
  ('thyme',      'Thym',              'herb',      'lamiaceae',      'Aromatique vivace méditerranéenne qui aime les sols secs et pauvres.',                                     90, 'high',   'low',    'chalky',   30),
  ('dill',       'Aneth',             'herb',      'apiaceae',       'Aromatique annuelle qui attire les insectes auxiliaires.',                                                 60, 'high',   'medium', 'loamy',    25),
  -- Flowers
  ('marigold',   'Œillet d''Inde',    'flower',    'asteraceae',     'Fleur répulsive contre les nématodes et certains insectes, compagne classique des tomates.',              70, 'high',   'medium', 'standard', 30),
  ('nasturtium', 'Capucine',          'flower',    'tropaeolaceae',  'Plante piège à pucerons, fleurs et feuilles comestibles.',                                                 60, 'high',   'low',    'standard', 30);

-- Calendars, declared with plant codes then converted to ids.
-- A plant can have several periods of the same type (e.g. spinach sown in spring and in autumn).
CREATE TEMPORARY TABLE tmp_period (
  code        VARCHAR(50),
  type        ENUM('sow_indoor', 'sow_outdoor', 'plant_out', 'harvest'),
  start_month TINYINT,
  end_month   TINYINT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

INSERT INTO tmp_period (code, type, start_month, end_month) VALUES
  ('tomato',     'sow_indoor',   3,  4), ('tomato',     'plant_out',   5,  6), ('tomato',     'harvest',  7, 10),
  ('carrot',     'sow_outdoor',  3,  7), ('carrot',     'harvest',     6, 11),
  ('lettuce',    'sow_indoor',   2,  3), ('lettuce',    'sow_outdoor', 3,  8), ('lettuce',    'plant_out',   4,  9), ('lettuce', 'harvest', 5, 11),
  ('radish',     'sow_outdoor',  3,  5), ('radish',     'sow_outdoor', 8,  9), ('radish',     'harvest',     4,  6), ('radish',  'harvest', 9, 11),
  ('green_bean', 'sow_outdoor',  5,  7), ('green_bean', 'harvest',     7, 10),
  ('pea',        'sow_outdoor',  2,  4), ('pea',        'sow_outdoor',10, 11), ('pea',        'harvest',     5,  7),
  ('zucchini',   'sow_indoor',   4,  4), ('zucchini',   'sow_outdoor', 5,  6), ('zucchini',   'plant_out',   5,  6), ('zucchini', 'harvest', 7, 10),
  ('cucumber',   'sow_indoor',   4,  4), ('cucumber',   'sow_outdoor', 5,  6), ('cucumber',   'plant_out',   5,  6), ('cucumber', 'harvest', 7,  9),
  ('potato',     'plant_out',    3,  5), ('potato',     'harvest',     6,  9),
  ('onion',      'sow_outdoor',  2,  4), ('onion',      'plant_out',   3,  4), ('onion',      'plant_out',   9, 10), ('onion',   'harvest', 6,  9),
  ('garlic',     'plant_out',   10, 12), ('garlic',     'plant_out',   2,  3), ('garlic',     'harvest',     6,  7),
  ('leek',       'sow_indoor',   2,  3), ('leek',       'plant_out',   6,  7), ('leek',       'harvest',     9,  3),
  ('spinach',    'sow_outdoor',  2,  4), ('spinach',    'sow_outdoor', 8, 10), ('spinach',    'harvest',     4,  6), ('spinach', 'harvest', 10, 12),
  ('cabbage',    'sow_indoor',   3,  4), ('cabbage',    'plant_out',   5,  7), ('cabbage',    'harvest',     7,  3),
  ('beetroot',   'sow_outdoor',  4,  6), ('beetroot',   'harvest',     7, 10),
  ('pepper',     'sow_indoor',   2,  3), ('pepper',     'plant_out',   5,  6), ('pepper',     'harvest',     7, 10),
  ('eggplant',   'sow_indoor',   2,  3), ('eggplant',   'plant_out',   5,  6), ('eggplant',   'harvest',     7,  9),
  ('squash',     'sow_indoor',   4,  4), ('squash',     'sow_outdoor', 5,  6), ('squash',     'plant_out',   5,  6), ('squash',   'harvest', 9, 10),
  ('corn',       'sow_indoor',   4,  4), ('corn',       'sow_outdoor', 5,  6), ('corn',       'plant_out',   5,  6), ('corn',     'harvest', 8,  9),
  ('celery',     'sow_indoor',   3,  4), ('celery',     'plant_out',   5,  6), ('celery',     'harvest',     9, 11),
  ('fennel',     'sow_outdoor',  6,  7), ('fennel',     'harvest',     9, 11),
  ('turnip',     'sow_outdoor',  3,  4), ('turnip',     'sow_outdoor', 7,  9), ('turnip',     'harvest',     5,  6), ('turnip',   'harvest', 9, 12),
  ('strawberry', 'plant_out',    8,  9), ('strawberry', 'plant_out',   3,  4), ('strawberry', 'harvest',     5,  7),
  ('basil',      'sow_indoor',   3,  4), ('basil',      'sow_outdoor', 5,  6), ('basil',      'plant_out',   5,  6), ('basil',    'harvest', 6, 10),
  ('parsley',    'sow_outdoor',  3,  8), ('parsley',    'harvest',     5, 11),
  ('chives',     'sow_outdoor',  3,  5), ('chives',     'plant_out',   3,  5), ('chives',     'plant_out',   9, 10), ('chives',   'harvest', 4, 10),
  ('thyme',      'sow_indoor',   3,  4), ('thyme',      'plant_out',   4,  6), ('thyme',      'plant_out',   9, 10), ('thyme',    'harvest', 1, 12),
  ('dill',       'sow_outdoor',  4,  7), ('dill',       'harvest',     6,  9),
  ('marigold',   'sow_indoor',   3,  4), ('marigold',   'plant_out',   5,  6),
  ('nasturtium', 'sow_outdoor',  4,  6), ('nasturtium', 'harvest',     6, 10);

INSERT INTO plant_period (plant_id, type, start_month, end_month)
SELECT p.id, t.type, t.start_month, t.end_month
FROM tmp_period t
JOIN plant p ON p.code = t.code;

DROP TEMPORARY TABLE tmp_period;

-- Associations are declared with plant codes, then converted to ids.
-- LEAST/GREATEST store each pair with plant_id_1 < plant_id_2 (see schema.sql).
CREATE TEMPORARY TABLE tmp_association (
  code_1        VARCHAR(50),
  code_2        VARCHAR(50),
  relation_type ENUM('positive', 'negative'),
  comment       TEXT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

INSERT INTO tmp_association (code_1, code_2, relation_type, comment) VALUES
  -- Positive
  ('tomato',     'basil',      'positive', 'Le basilic éloigne certains ravageurs et favoriserait la saveur des tomates.'),
  ('tomato',     'marigold',   'positive', 'L''œillet d''Inde repousse les nématodes et les aleurodes.'),
  ('tomato',     'carrot',     'positive', 'Les carottes ameublissent le sol autour des tomates.'),
  ('tomato',     'parsley',    'positive', 'Le persil attire les insectes auxiliaires.'),
  ('tomato',     'nasturtium', 'positive', 'La capucine attire les pucerons loin des tomates.'),
  ('carrot',     'onion',      'positive', 'L''oignon éloigne la mouche de la carotte, la carotte celle de l''oignon.'),
  ('carrot',     'leek',       'positive', 'Le poireau éloigne la mouche de la carotte, et inversement.'),
  ('carrot',     'lettuce',    'positive', 'Occupation complémentaire du sol : racine profonde et feuilles en surface.'),
  ('carrot',     'radish',     'positive', 'Les radis, rapides, marquent les rangs et ameublissent le sol pour les carottes.'),
  ('carrot',     'chives',     'positive', 'La ciboulette éloigne la mouche de la carotte.'),
  ('carrot',     'pea',        'positive', 'Le pois enrichit le sol en azote.'),
  ('lettuce',    'radish',     'positive', 'Cultures rapides qui se partagent bien l''espace.'),
  ('lettuce',    'strawberry', 'positive', 'La laitue couvre le sol entre les fraisiers.'),
  ('lettuce',    'cucumber',   'positive', 'Le feuillage du concombre apporte de l''ombre à la laitue en été.'),
  ('lettuce',    'beetroot',   'positive', 'Enracinements différents, bonne occupation du sol.'),
  ('green_bean', 'corn',       'positive', 'Le maïs sert de tuteur, le haricot apporte de l''azote (culture des « trois sœurs »).'),
  ('green_bean', 'squash',     'positive', 'La courge couvre le sol, le haricot l''enrichit en azote (« trois sœurs »).'),
  ('corn',       'squash',     'positive', 'La courge garde le sol frais au pied du maïs (« trois sœurs »).'),
  ('green_bean', 'potato',     'positive', 'Le haricot éloignerait le doryphore de la pomme de terre.'),
  ('green_bean', 'eggplant',   'positive', 'Le haricot éloignerait le doryphore de l''aubergine.'),
  ('green_bean', 'zucchini',   'positive', 'Le haricot enrichit le sol en azote pour la courgette gourmande.'),
  ('cucumber',   'dill',       'positive', 'L''aneth attire les insectes auxiliaires utiles au concombre.'),
  ('zucchini',   'nasturtium', 'positive', 'La capucine attire les pucerons loin des courgettes.'),
  ('cabbage',    'celery',     'positive', 'Le céleri éloigne la piéride du chou.'),
  ('cabbage',    'thyme',      'positive', 'Le thym éloigne la piéride du chou.'),
  ('beetroot',   'onion',      'positive', 'Bonne cohabitation, besoins complémentaires.'),
  ('strawberry', 'garlic',     'positive', 'L''ail limiterait les maladies cryptogamiques du fraisier.'),
  ('strawberry', 'leek',       'positive', 'Le poireau limiterait les maladies du fraisier.'),
  ('strawberry', 'spinach',    'positive', 'L''épinard couvre le sol entre les fraisiers.'),
  ('leek',       'celery',     'positive', 'Le céleri et le poireau se protègent mutuellement de leurs ravageurs.'),
  ('pepper',     'basil',      'positive', 'Le basilic éloigne certains ravageurs du poivron.'),
  ('radish',     'pea',        'positive', 'Cultures de printemps compatibles.'),
  ('radish',     'spinach',    'positive', 'Cultures rapides compatibles.'),
  ('potato',     'marigold',   'positive', 'L''œillet d''Inde repousse les nématodes.'),
  -- Negative
  ('tomato',     'potato',     'negative', 'Même famille (solanacées) : elles partagent le mildiou et les mêmes ravageurs.'),
  ('tomato',     'fennel',     'negative', 'Le fenouil freine la croissance de la tomate.'),
  ('tomato',     'cabbage',    'negative', 'Concurrence et croissance ralentie de part et d''autre.'),
  ('tomato',     'corn',       'negative', 'Partagent certains ravageurs (noctuelles).'),
  ('green_bean', 'onion',      'negative', 'Les alliacées freinent la croissance des haricots.'),
  ('green_bean', 'garlic',     'negative', 'Les alliacées freinent la croissance des haricots.'),
  ('green_bean', 'leek',       'negative', 'Les alliacées freinent la croissance des haricots.'),
  ('green_bean', 'fennel',     'negative', 'Le fenouil freine la croissance du haricot.'),
  ('pea',        'onion',      'negative', 'Les alliacées freinent la croissance des pois.'),
  ('pea',        'garlic',     'negative', 'Les alliacées freinent la croissance des pois.'),
  ('potato',     'squash',     'negative', 'Concurrence pour l''eau et les nutriments, sensibles au même mildiou.'),
  ('potato',     'cucumber',   'negative', 'Le concombre favoriserait le mildiou de la pomme de terre.'),
  ('cabbage',    'strawberry', 'negative', 'Le chou gêne le développement du fraisier.'),
  ('carrot',     'dill',       'negative', 'Même famille (apiacées) : l''aneth en fleurs peut freiner la carotte.');

INSERT INTO plant_association (plant_id_1, plant_id_2, relation_type, comment)
SELECT LEAST(p1.id, p2.id), GREATEST(p1.id, p2.id), t.relation_type, t.comment
FROM tmp_association t
JOIN plant p1 ON p1.code = t.code_1
JOIN plant p2 ON p2.code = t.code_2;

DROP TEMPORARY TABLE tmp_association;
