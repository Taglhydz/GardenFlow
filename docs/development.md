# Development

How to run GardenFlow on your PC, change the database, build a release of the app and add a language. To put the server online, see [deploy/README.md](../deploy/README.md).

## Everyday development (Android phone over USB)

With the phone plugged in (USB debugging enabled) and `API_BASE_URL=http://localhost:3000/api` in `frontend/.env` :

```bash
.\dev        # or double-click dev.cmd
```

It forwards the phone's port 3000 to the PC (`adb reverse`), starts the backend in a new window and runs the app on the phone. No ngrok or IP address needed. Run it again after re-plugging the phone.

## Backend

```bash
cd backend
npm install
cp .env.example .env        # then fill in DB_* and JWT_SECRET
npm run migrate             # creates the tables and loads the plant catalog
npm run dev                 # http://localhost:3000/api
```

| Script | Description |
| --- | --- |
| `npm run dev` / `npm run prod` | Start the API (in production, refuses to start while migrations are pending) |
| `npm run migrate` | Apply the pending migrations to `DB_NAME` |
| `npm run migrate:status` | Show the applied and pending migrations |
| `npm run migrate:new -- <description>` | Create the next migration file, to fill in |
| `npm run db:baseline` | Once, for a database created before the migrations (with the old `schema.sql`) |
| `npm run db:reset` | ⚠️ Drop all the tables of `DB_NAME` and apply all the migrations (refused in production) |
| `npm run set-role -- <email> admin` | Give the admin role to an existing user (there is no public way to become admin) |
| `npm test` | Integration tests on the database `DB_NAME_TEST` (⚠️ wiped on each run) |

### Changing the database

The database is changed only by migrations : numbered SQL files in `backend/src/database/migrations`, applied once and in order. The table `schema_migrations` remembers which ones were applied.

1. `npm run migrate:new -- add password reset` creates e.g. `003_add_password_reset.sql`
2. Write the SQL in it (`ALTER TABLE ...`, `INSERT ...`), then `npm run migrate`
3. Commit the file with the code that uses it ; after a `git pull`, run `npm run migrate`

A migration that is applied somewhere must **never be modified** (the server detects it with a checksum) : fix it with a new migration. MySQL can't roll back a `CREATE` / `ALTER TABLE` : keep each migration small, and try it on a copy of the production data before deploying.

The test database must exist and be accessible by the MySQL user, for example (as root) :

```sql
CREATE DATABASE gardenflow_test;
GRANT ALL PRIVILEGES ON gardenflow_test.* TO 'gardenuser'@'localhost';
```

## Frontend

```bash
cd frontend
cp .env.example .env        # API_BASE_URL=http://localhost:3000/api works on a phone with .\dev (adb reverse)
flutter pub get
flutter run
flutter test
```

### Release build

`frontend/.env` is the dev configuration. A release build takes its values from `frontend/config/prod.json` (not committed, copy of `config/prod.example.json`), which wins over `.env` :

```json
{
  "API_BASE_URL": "https://api.your-domain.com/api",
  "GOOGLE_CLIENT_ID": "<OAuth client id of type Web, same as the backend>"
}
```

```bash
cd frontend
flutter build appbundle --release --dart-define-from-file=config/prod.json   # Play Store : build/app/outputs/bundle/release/app-release.aab
flutter build apk --release --dart-define-from-file=config/prod.json         # APK to install directly
```

The release builds are signed with the upload key of the Play Store, read from `frontend/android/key.properties` (not committed, copy of `key.properties.example`). The keystore itself is kept **outside the repository** and backed up. Without `key.properties`, the build is signed with the debug key : it installs on a phone, but the Play Store refuses it.

```bash
keytool -genkeypair -v -keystore C:/Users/<you>/keys/gardenflow-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload   # once
keytool -list -v -keystore C:/Users/<you>/keys/gardenflow-upload.jks -alias upload                                                 # SHA-1 / SHA-256 (Google sign-in)
```

Without `--dart-define-from-file`, the app uses the `.env` values (`localhost`). Only public values go in these files (the Google client id is not a secret) : they end up inside the app. Increase the build number (`version: 1.0.0+N` in `pubspec.yaml`) before each upload to the store.

## Translations

- Interface texts : `frontend/assets/translations/<lang>.json`, every language must have the same keys (checked by `flutter test`).
- Plant catalog : the database stores the texts **in French** with a stable `code` (e.g. `tomato`). Other languages translate them in their JSON file (`plants.<code>.name`, `plants.<code>.description`, `plant_associations.<codeA>__<codeB>` with codes sorted alphabetically). Without a translation the French text is displayed. `npm test` checks that `en.json` translates every seeded plant.
- Adding a language = adding a JSON file and its `Locale` in `main.dart`, no database change.
