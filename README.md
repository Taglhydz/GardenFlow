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
cp .env.example .env        # API_BASE_URL : use your computer's IP (not localhost) for a physical phone
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
| `GET /plants`, `GET /plants/:id`, `GET /plant-associations` | Logged in user |
| `POST / PATCH / DELETE /plants`, `/plant-associations` | Admin |

- The user is always taken from the token, never from the request body or URL. A resource of another user answers `404`.
- `PATCH` only modifies the fields that are sent and returns the updated resource.
- Deletions are real deletions : deleting a garden deletes its parcels and crops. A plant used by a crop can't be deleted (`409 RESOURCE_IN_USE`).
- Errors have the format `{ "code": "EMAIL_ALREADY_USED", "message": "...", "details": [...] }`. The app translates `code` with the `errors.<code>` translation keys.

## Translations

- Interface texts : `frontend/assets/translations/<lang>.json`, every language must have the same keys (checked by `flutter test`).
- Plant catalog : the database stores the texts **in French** with a stable `code` (e.g. `tomato`). Other languages translate them in their JSON file (`plants.<code>.name`, `plants.<code>.description`, `plant_associations.<codeA>__<codeB>` with codes sorted alphabetically). Without a translation the French text is displayed. `npm test` checks that `en.json` translates every seeded plant.
- Adding a language = adding a JSON file and its `Locale` in `main.dart`, no database change.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
