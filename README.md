# GardenFlow

GardenFlow is a mobile app designed to help gardeners efficiently plan and manage their gardens. It provides optimal planting layouts, crop associations, and seasonal advice based on garden size, plant choices, and soil conditions.

## Planned Features

- Create and visualize your garden layout using custom drawings or shapes.

- Select the vegetables and plants you want to grow.

- Get smart suggestions on what to plant where and when, considering garden size, soil type, and season.

- Discover beneficial plant associations and soil improvement recommendations.

- Add user authentication and profiles.

## Tech Stack

- Frontend: Flutter (mobile app), Riverpod (state management), easy_localization (FR / EN)

- Backend: Express.js 5 (Node.js framework), zod (validation), JWT authentication

- Database: MySQL 8

## Getting started

### Everyday development (Android phone over USB)

With the phone plugged in (USB debugging enabled) and `API_BASE_URL=http://localhost:3000/api` in `frontend/.env` :

```bash
.\dev        # or double-click dev.cmd
```

It forwards the phone's port 3000 to the PC (`adb reverse`), starts the backend in a new window and runs the app on the phone. No ngrok or IP address needed. Run it again after re-plugging the phone.

### Backend

```bash
cd backend
npm install
cp .env.example .env        # then fill in DB_* and JWT_SECRET
npm run db:reset            # ⚠️ recreates all tables and loads the plant catalog
npm run dev                 # http://localhost:3000/api
```

| Script | Description |
| --- | --- |
| `npm run dev` / `npm run prod` | Start the API |
| `npm run db:reset` | Drop and recreate the tables of `DB_NAME`, then load `seed.sql` |
| `npm run set-role -- <email> admin` | Give the admin role to an existing user (there is no public way to become admin) |
| `npm test` | Integration tests on the database `DB_NAME_TEST` (⚠️ wiped on each run) |

The test database must exist and be accessible by the MySQL user, for example (as root) :

```sql
CREATE DATABASE gardenflow_test;
GRANT ALL PRIVILEGES ON gardenflow_test.* TO 'gardenuser'@'localhost';
```

### Frontend

```bash
cd frontend
cp .env.example .env        # API_BASE_URL=http://localhost:3000/api works on a phone with .\dev (adb reverse)
flutter pub get
flutter run
flutter test
```

## API

All routes are prefixed with `/api`. Except `/auth/*` and `/health`, they require the header `Authorization: Bearer <token>`.

| Route | Access |
| --- | --- |
| `POST /auth/register`, `POST /auth/login` | Public (rate limited) |
| `GET / PATCH / DELETE /users/me`, `PATCH /users/me/password` | Logged in user |
| `GET / PATCH / DELETE /users/:id`, `GET /users` | Admin |
| `GET / POST /gardens`, `GET / PATCH / DELETE /gardens/:id` | Owner only |
| `GET / POST /gardens/:gardenId/parcels`, `GET / PATCH / DELETE /parcels/:id` | Owner of the garden |
| `GET / POST /parcels/:parcelId/crops`, `GET / PATCH / DELETE /crops/:id` | Owner of the garden |
| `GET /gardens/:gardenId/crops` (all the crops of a garden, for the plan) | Owner of the garden |
| `GET /parcels/:id/suggestions?month=5` | Owner of the garden |
| `GET /plants`, `GET /plants/:id`, `GET /plant-associations` | Logged in user |
| `POST / PATCH / DELETE /plants`, `/plant-associations` | Admin |

- The user is always taken from the token, never from the request body or URL. A resource of another user answers `404`.
- `PATCH` only modifies the fields that are sent and returns the updated resource.
- Deletions are real deletions : deleting a garden deletes its parcels and crops. A plant used by a crop can't be deleted (`409 RESOURCE_IN_USE`).
- Plants are returned with their `family` and their calendar `periods` : `[{ type, start_month, end_month }]` with `type` = `sow_indoor`, `sow_outdoor`, `plant_out` or `harvest`. A plant can have several periods of the same type (spinach is sown in spring and in autumn), and a period can wrap around the year (10 -> 3).
- The parcel area is computed from `width x length`.
- Errors have the format `{ "code": "EMAIL_ALREADY_USED", "message": "...", "details": [...] }`. The app translates `code` with the `errors.<code>` translation keys.

## Suggestions

`GET /parcels/:id/suggestions?month=5` ranks the plants that can be sown or planted in the parcel that month (nothing is stored, it is computed on each request). The rules are in `backend/src/services/suggestionEngine.js` (weights in `WEIGHTS`, unit tests in `backend/tests/suggestionEngine.test.js`). Each plant starts at 50 points :

| Rule | Effect |
| --- | --- |
| Season | can go in the ground this month : +15. Only sowing under cover this month : listed, without bonus |
| Soil | preferred soil = parcel soil : +10, different : -5 (a `standard` soil suits everything) |
| Sunlight / moisture | matching : bonus, not enough sun or too dry / too wet : penalty |
| Associations | good / bad companion among the crops in the ground of the parcel : +12 / -20, of an adjacent parcel (gap of 50 cm at most) : +6 / -10 |
| Crop rotation | same botanical family harvested in the parcel less than 1 / 2 / 3 years ago : -25 / -15 / -8 |

Each score change comes with a reason `{ code, impact, params }`, translated in the app with `suggestion_reasons.<code>`.

## Translations

- Interface texts : `frontend/assets/translations/<lang>.json`, every language must have the same keys (checked by `flutter test`).
- Plant catalog : the database stores the texts **in French** with a stable `code` (e.g. `tomato`). Other languages translate them in their JSON file (`plants.<code>.name`, `plants.<code>.description`, `plant_associations.<codeA>__<codeB>` with codes sorted alphabetically). Without a translation the French text is displayed. `npm test` checks that `en.json` translates every seeded plant.
- Adding a language = adding a JSON file and its `Locale` in `main.dart`, no database change.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
