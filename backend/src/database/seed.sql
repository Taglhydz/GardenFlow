-- =========================
-- GardenFlow reference data
-- =========================
-- Plant catalog and plant associations. Run after schema.sql (`npm run db:reset` runs both).
-- Texts are in French ; the Flutter app translates them with the plant `code`
-- (plants.<code>.name / plants.<code>.description in assets/translations/*.json).
--
-- Months are indicative for a temperate climate (France). Sowing periods include
-- sowing under cover. Ranges may wrap around the year (10 -> 3 = October to March).

INSERT INTO plant
  (code, name, type, description, sow_start_month, sow_end_month, harvest_start_month, harvest_end_month, sunlight_need, water_need, preferred_soil, spacing_cm)
VALUES
  -- Vegetables
  ('tomato',     'Tomate',            'vegetable', 'Légume-fruit d''été gourmand en chaleur. Semer sous abri, repiquer après les dernières gelées.',         3,  4,  7, 10, 'high',   'medium', 'humus',    50),
  ('carrot',     'Carotte',           'vegetable', 'Racine à semer en place dans une terre légère et sans cailloux.',                                        3,  7,  6, 11, 'high',   'medium', 'sandy',     5),
  ('lettuce',    'Laitue',            'vegetable', 'Salade à croissance rapide, à semer en échelonnant pour récolter toute la saison.',                       2,  9,  4, 11, 'medium', 'medium', 'loamy',    25),
  ('radish',     'Radis',             'vegetable', 'Récolte en 4 semaines environ, idéal pour débuter.',                                                      3,  9,  4, 10, 'medium', 'medium', 'loamy',     5),
  ('green_bean', 'Haricot vert',      'vegetable', 'Légumineuse frileuse à semer en place quand la terre est réchauffée. Enrichit le sol en azote.',        5,  7,  7, 10, 'high',   'medium', 'loamy',    10),
  ('pea',        'Petit pois',        'vegetable', 'Légumineuse de saison fraîche, à semer tôt au printemps. Enrichit le sol en azote.',                     2,  5,  5,  7, 'medium', 'medium', 'loamy',     5),
  ('zucchini',   'Courgette',         'vegetable', 'Plante vigoureuse et très productive, gourmande en eau et en matière organique.',                        4,  6,  6, 10, 'high',   'high',   'humus',   100),
  ('cucumber',   'Concombre',         'vegetable', 'Aime la chaleur et un arrosage régulier, peut être palissé.',                                            4,  5,  7,  9, 'high',   'high',   'humus',    60),
  ('potato',     'Pomme de terre',    'vegetable', 'Tubercule à planter au printemps, à butter au cours de la croissance.',                                   3,  5,  6,  9, 'high',   'medium', 'loamy',    35),
  ('onion',      'Oignon',            'vegetable', 'Bulbe à semer ou planter en bulbilles, n''aime pas l''excès d''eau.',                                   2,  4,  7,  9, 'high',   'low',    'loamy',    10),
  ('garlic',     'Ail',               'vegetable', 'Caïeux à planter en automne ou en fin d''hiver dans un sol bien drainé.',                                10,  3,  6,  7, 'high',   'low',    'sandy',    10),
  ('leek',       'Poireau',           'vegetable', 'Légume d''hiver très rustique, à repiquer en été.',                                                       2,  4,  9,  3, 'medium', 'medium', 'loamy',    15),
  ('spinach',    'Épinard',           'vegetable', 'Légume-feuille de saison fraîche qui monte vite en graines par temps chaud.',                             2, 10,  4, 12, 'medium', 'high',   'humus',    15),
  ('cabbage',    'Chou',              'vegetable', 'Légume exigeant en nutriments, apprécie les sols lourds et frais.',                                      3,  6,  7,  3, 'medium', 'high',   'clay',     50),
  ('beetroot',   'Betterave',         'vegetable', 'Racine facile à cultiver, se conserve bien.',                                                             4,  6,  7, 10, 'high',   'medium', 'loamy',    10),
  ('pepper',     'Poivron',           'vegetable', 'Très frileux, à semer au chaud en fin d''hiver.',                                                         2,  3,  7, 10, 'high',   'medium', 'humus',    45),
  ('eggplant',   'Aubergine',         'vegetable', 'Demande beaucoup de chaleur et de soleil pour bien produire.',                                            2,  3,  7,  9, 'high',   'medium', 'humus',    60),
  ('squash',     'Courge',            'vegetable', 'Plante coureuse qui prend beaucoup de place, récolte avant les gelées.',                                   4,  5,  9, 10, 'high',   'high',   'humus',   150),
  ('corn',       'Maïs doux',         'vegetable', 'À semer en bloc plutôt qu''en ligne pour une bonne pollinisation.',                                       5,  6,  8,  9, 'high',   'medium', 'loamy',    30),
  ('celery',     'Céleri',            'vegetable', 'Aime les sols riches et frais, arrosage régulier indispensable.',                                          3,  4,  9, 11, 'medium', 'high',   'humus',    40),
  ('fennel',     'Fenouil',           'vegetable', 'Bulbe à semer en été, freine la croissance de nombreuses plantes voisines.',                              5,  7,  8, 11, 'high',   'medium', 'loamy',    30),
  ('turnip',     'Navet',             'vegetable', 'Racine rapide, surtout cultivée en fin d''été pour l''automne.',                                           3,  9,  5, 11, 'medium', 'medium', 'loamy',    10),
  -- Fruits
  ('strawberry', 'Fraisier',          'fruit',     'Vivace à planter en fin d''été ou au printemps, se multiplie par stolons.',                               8,  9,  5,  7, 'high',   'medium', 'humus',    30),
  -- Herbs
  ('basil',      'Basilic',           'herb',      'Aromatique frileuse, à semer au chaud et à pincer régulièrement.',                                        3,  6,  6, 10, 'high',   'medium', 'humus',    25),
  ('parsley',    'Persil',            'herb',      'Bisannuelle à la germination lente.',                                                                     3,  8,  5, 11, 'medium', 'medium', 'loamy',    15),
  ('chives',     'Ciboulette',        'herb',      'Vivace facile, repousse après chaque coupe.',                                                             3,  5,  4, 10, 'medium', 'medium', 'loamy',    20),
  ('thyme',      'Thym',              'herb',      'Aromatique vivace méditerranéenne qui aime les sols secs et pauvres.',                                    3,  5,  1, 12, 'high',   'low',    'chalky',   30),
  ('dill',       'Aneth',             'herb',      'Aromatique annuelle qui attire les insectes auxiliaires.',                                                4,  7,  6,  9, 'high',   'medium', 'loamy',    25),
  -- Flowers
  ('marigold',   'Œillet d''Inde',    'flower',    'Fleur répulsive contre les nématodes et certains insectes, compagne classique des tomates.',             3,  5,  6, 10, 'high',   'medium', 'standard', 30),
  ('nasturtium', 'Capucine',          'flower',    'Plante piège à pucerons, fleurs et feuilles comestibles.',                                                4,  6,  6, 10, 'high',   'low',    'standard', 30);

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
