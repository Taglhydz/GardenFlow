# API

All routes are prefixed with `/api`. Except `/auth/*` and `/health`, they require the header `Authorization: Bearer <token>`.

| Route | Access |
| --- | --- |
| `POST /auth/register`, `POST /auth/login` | Public (rate limited) |
| `POST /auth/forgot-password` : emails a link to a web page (`GET / POST /auth/reset-password`) to choose a new password, valid 1 hour and once | Public (rate limited) |
| `GET / PATCH / DELETE /users/me`, `PATCH /users/me/password` | Logged in user |
| `GET / PATCH / DELETE /users/:id`, `GET /users` | Admin |
| `GET / POST /gardens`, `GET / PATCH / DELETE /gardens/:id` | Owner only |
| `GET / POST /gardens/:gardenId/parcels`, `GET / PATCH / DELETE /parcels/:id` | Owner of the garden |
| `GET / POST /parcels/:parcelId/crops`, `GET / PATCH / DELETE /crops/:id` | Owner of the garden |
| `GET / POST /parcels/:parcelId/zones`, `GET / PATCH / DELETE /zones/:id` | Owner of the garden |
| `GET /gardens/:gardenId/crops`, `GET /gardens/:gardenId/zones` (everything for the plans in one request) | Owner of the garden |
| `GET /parcels/:id/suggestions?month=5`, `GET /zones/:id/suggestions?month=5` | Owner of the garden |
| `GET /plants`, `GET /plants/:id`, `GET /plant-associations` | Logged in user |
| `POST / PATCH / DELETE /plants`, `/plant-associations` | Admin |

- The user is always taken from the token, never from the request body or URL. A resource of another user answers `404`.
- `PATCH` only modifies the fields that are sent and returns the updated resource.
- Deletions are real deletions : deleting a garden deletes its parcels and crops. A plant used by a crop can't be deleted (`409 RESOURCE_IN_USE`).
- Plants are returned with their `family` and their calendar `periods` : `[{ type, start_month, end_month }]` with `type` = `sow_indoor`, `sow_outdoor`, `plant_out` or `harvest`. A plant can have several periods of the same type (spinach is sown in spring and in autumn), and a period can wrap around the year (10 -> 3).
- Parcels and zones are free shapes : `shape` is a list of 3 to 50 points `[{ "x": 0, "y": 0 }, ...]` in meters, without crossing sides. A parcel shape is relative to its position (`pos_x`, `pos_y`) : moving a parcel only changes its position. A zone shape is relative to the position of its parcel, so the zones follow the parcel. The areas are computed from the shapes.
- A zone must be inside its parcel and must not overlap another zone (`ZONE_OUTSIDE_PARCEL`, `ZONES_OVERLAP`). A new parcel shape that would leave a zone outside is refused (`ZONES_OUTSIDE_PARCEL`). Deleting a zone keeps its crops in the parcel (`zone_id` becomes null).
- A crop can be placed in a zone of its parcel (`zone_id`), or in the whole parcel (`zone_id` null).
- Errors have the format `{ "code": "EMAIL_ALREADY_USED", "message": "...", "details": [...] }`. The app translates `code` with the `errors.<code>` translation keys.

## Suggestions

`GET /zones/:id/suggestions?month=5` (or `/parcels/:id/suggestions` for the whole parcel) ranks the plants that can be sown or planted there that month (nothing is stored, it is computed on each request). The rules are in `backend/src/services/suggestionEngine.js` (weights in `WEIGHTS`, unit tests in `backend/tests/suggestionEngine.test.js`). Each plant starts at 50 points :

| Rule | Effect |
| --- | --- |
| Season | can go in the ground this month : +15. Only sowing under cover this month : listed, without bonus |
| Soil | preferred soil = parcel soil : +10, different : -5 (a `standard` soil suits everything) |
| Sunlight / moisture | matching : bonus, not enough sun or too dry / too wet : penalty |
| Associations | good / bad companion among the crops in the ground of the zone : +12 / -20, elsewhere in the parcel : +8 / -14, in an adjacent parcel (gap of 50 cm at most between the shapes) : +6 / -10 |
| Crop rotation | same botanical family harvested in the zone (or in the whole parcel) less than 1 / 2 / 3 years ago : -25 / -15 / -8 |
| Space | number of plants that fit in the zone with the spacing of the plant (info), -30 if not even one fits |

Each score change comes with a reason `{ code, impact, params }`, translated in the app with `suggestion_reasons.<code>`.
