/**
 * Integration tests : real HTTP requests on the Express app and a real MySQL database.
 * ⚠️  The database DB_NAME_TEST is wiped and re-seeded before the tests.
 */
const request = require('supertest');
const app     = require('../src/app');
const db      = require('../src/database/db');
const { resetDatabase } = require('../scripts/db-reset');

const api = request(app);

const register = async (email, extra = {}) => {
  const res = await api.post('/api/auth/register').send({ username: 'tester', email, password: 'password123', ...extra });
  expect(res.status).toBe(201);
  return { token: res.body.token, user: res.body.user };
};

const auth = (token) => ({ Authorization: `Bearer ${token}` });

let alice; // owner of the test data
let bob;   // another user, must never see alice's data
let admin;

beforeAll(async () => {
  await resetDatabase();
  alice = await register('alice@test.dev');
  bob   = await register('bob@test.dev');
  admin = await register('admin@test.dev');
  await db.query("UPDATE user SET role = 'admin' WHERE id = ?", [admin.user.id]);
});

afterAll(() => db.end());

describe('health and errors', () => {
  test('GET /api/health', async () => {
    const res = await api.get('/api/health');
    expect(res.status).toBe(200);
  });

  test('unknown route -> 404 ROUTE_NOT_FOUND', async () => {
    const res = await api.get('/api/nope');
    expect(res.status).toBe(404);
    expect(res.body.code).toBe('ROUTE_NOT_FOUND');
  });

  test('malformed JSON -> 400 INVALID_JSON', async () => {
    const res = await api.post('/api/auth/login').set('Content-Type', 'application/json').send('{"email":');
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('INVALID_JSON');
  });
});

describe('auth', () => {
  test('register ignores a role sent by the client', async () => {
    const res = await api.post('/api/auth/register')
      .send({ username: 'hacker', email: 'hacker@test.dev', password: 'password123', role: 'admin' });
    expect(res.status).toBe(201);
    expect(res.body.user.role).toBe('user');
    expect(res.body.user.password_hash).toBeUndefined();
  });

  test('register normalizes the email and keeps the birthdate as YYYY-MM-DD', async () => {
    const res = await api.post('/api/auth/register')
      .send({ username: 'carol', email: '  Carol@Test.DEV ', password: 'password123', birthdate: '2000-01-01' });
    expect(res.status).toBe(201);
    expect(res.body.user.email).toBe('carol@test.dev');
    expect(res.body.user.birthdate).toBe('2000-01-01');
  });

  test('register without birthdate works (optional)', async () => {
    const res = await api.post('/api/auth/register').send({ username: 'dave', email: 'dave@test.dev', password: 'password123' });
    expect(res.status).toBe(201);
    expect(res.body.user.birthdate).toBeNull();
  });

  test('register with an existing email -> 409 EMAIL_ALREADY_USED', async () => {
    const res = await api.post('/api/auth/register').send({ username: 'alice2', email: 'ALICE@test.dev', password: 'password123' });
    expect(res.status).toBe(409);
    expect(res.body.code).toBe('EMAIL_ALREADY_USED');
  });

  test('register with invalid data -> 400 VALIDATION_ERROR with details', async () => {
    const res = await api.post('/api/auth/register').send({ username: 'x', email: 'not-an-email', password: 'short' });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('VALIDATION_ERROR');
    expect(res.body.details.map((d) => d.field).sort()).toEqual(['email', 'password', 'username']);
  });

  test('register with a birthdate in the future -> 400', async () => {
    const res = await api.post('/api/auth/register').send({ username: 'future', email: 'future@test.dev', password: 'password123', birthdate: '2999-01-01' });
    expect(res.status).toBe(400);
  });

  test('login OK', async () => {
    const res = await api.post('/api/auth/login').send({ email: 'alice@test.dev', password: 'password123' });
    expect(res.status).toBe(200);
    expect(res.body.token).toBeDefined();
    expect(res.body.user.password_hash).toBeUndefined();
  });

  test('wrong password and unknown email give the same error', async () => {
    const wrong   = await api.post('/api/auth/login').send({ email: 'alice@test.dev',   password: 'wrongpassword' });
    const unknown = await api.post('/api/auth/login').send({ email: 'unknown@test.dev', password: 'password123' });
    expect(wrong.status).toBe(401);
    expect(unknown.status).toBe(401);
    expect(wrong.body).toEqual(unknown.body);
    expect(wrong.body.code).toBe('INVALID_CREDENTIALS');
  });

  test('no token -> 401 UNAUTHORIZED', async () => {
    const res = await api.get('/api/gardens');
    expect(res.status).toBe(401);
    expect(res.body.code).toBe('UNAUTHORIZED');
  });

  test('invalid token -> 401 INVALID_TOKEN', async () => {
    const res = await api.get('/api/gardens').set(auth('abc.def.ghi'));
    expect(res.status).toBe(401);
    expect(res.body.code).toBe('INVALID_TOKEN');
  });
});

describe('gardens ownership', () => {
  let gardenId;

  test('create : the owner is the logged in user, not the user_id of the body', async () => {
    const res = await api.post('/api/gardens').set(auth(alice.token))
      .send({ name: 'Potager', location: 'Lyon', user_id: bob.user.id });
    expect(res.status).toBe(201);
    expect(res.body.user_id).toBe(alice.user.id);
    gardenId = res.body.id;
  });

  test('list only returns my gardens', async () => {
    await api.post('/api/gardens').set(auth(bob.token)).send({ name: 'Jardin de Bob' });

    const res = await api.get('/api/gardens').set(auth(alice.token));
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].id).toBe(gardenId);
  });

  test("another user can't read, modify or delete my garden (404)", async () => {
    expect((await api.get(`/api/gardens/${gardenId}`).set(auth(bob.token))).status).toBe(404);
    expect((await api.patch(`/api/gardens/${gardenId}`).set(auth(bob.token)).send({ name: 'Volé' })).status).toBe(404);
    expect((await api.delete(`/api/gardens/${gardenId}`).set(auth(bob.token))).status).toBe(404);

    const res = await api.get(`/api/gardens/${gardenId}`).set(auth(alice.token));
    expect(res.body.name).toBe('Potager');
  });

  test('partial update keeps the other fields and returns the garden', async () => {
    const res = await api.patch(`/api/gardens/${gardenId}`).set(auth(alice.token)).send({ description: 'Plein sud' });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ name: 'Potager', location: 'Lyon', description: 'Plein sud' });
  });

  test('empty strings are stored as null', async () => {
    const res = await api.patch(`/api/gardens/${gardenId}`).set(auth(alice.token)).send({ location: '   ' });
    expect(res.body.location).toBeNull();
  });

  test('empty update -> 400', async () => {
    const res = await api.patch(`/api/gardens/${gardenId}`).set(auth(alice.token)).send({});
    expect(res.status).toBe(400);
  });

  test('invalid id -> 400', async () => {
    const res = await api.get('/api/gardens/abc').set(auth(alice.token));
    expect(res.status).toBe(400);
  });
});

describe('parcels and crops', () => {
  let gardenId;
  let parcelId;
  let cropId;
  let tomatoId;

  beforeAll(async () => {
    const garden = await api.post('/api/gardens').set(auth(alice.token)).send({ name: 'Jardin parcelles' });
    gardenId = garden.body.id;
    const [[tomato]] = await db.query("SELECT id FROM plant WHERE code = 'tomato'");
    tomatoId = tomato.id;
  });

  test('create a parcel : decimals are returned as numbers and defaults are applied', async () => {
    const res = await api.post(`/api/gardens/${gardenId}/parcels`).set(auth(alice.token))
      .send({ name: 'Carré 1', width: 1.2, length: '2.5', soil_type: 'clay' });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ garden_id: gardenId, width: 1.2, length: 2.5, soil_type: 'clay', sunlight: 'medium', pos_x: 0 });
    parcelId = res.body.id;
  });

  test('invalid enum -> 400', async () => {
    const res = await api.post(`/api/gardens/${gardenId}/parcels`).set(auth(alice.token)).send({ name: 'X', soil_type: 'mud' });
    expect(res.status).toBe(400);
  });

  test("can't create a parcel in another user's garden", async () => {
    const res = await api.post(`/api/gardens/${gardenId}/parcels`).set(auth(bob.token)).send({ name: 'Intrus' });
    expect(res.status).toBe(404);
  });

  test("another user can't access my parcel", async () => {
    expect((await api.get(`/api/parcels/${parcelId}`).set(auth(bob.token))).status).toBe(404);
    expect((await api.get(`/api/gardens/${gardenId}/parcels`).set(auth(bob.token))).status).toBe(404);
    expect((await api.patch(`/api/parcels/${parcelId}`).set(auth(bob.token)).send({ name: 'x' })).status).toBe(404);
    expect((await api.delete(`/api/parcels/${parcelId}`).set(auth(bob.token))).status).toBe(404);
  });

  test('partial parcel update', async () => {
    const res = await api.patch(`/api/parcels/${parcelId}`).set(auth(alice.token)).send({ sunlight: 'high' });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ name: 'Carré 1', sunlight: 'high', soil_type: 'clay' });
  });

  test('create a crop', async () => {
    const res = await api.post(`/api/parcels/${parcelId}/crops`).set(auth(alice.token))
      .send({ plant_id: tomatoId, sow_date: '2026-04-01', expected_harvest_date: '2026-08-01' });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ parcel_id: parcelId, plant_id: tomatoId, sow_date: '2026-04-01' });
    cropId = res.body.id;
  });

  test('crop with an unknown plant -> 400 INVALID_REFERENCE', async () => {
    const res = await api.post(`/api/parcels/${parcelId}/crops`).set(auth(alice.token)).send({ plant_id: 999999 });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('INVALID_REFERENCE');
  });

  test('harvest before sowing -> 400, also when only one date is updated', async () => {
    const create = await api.post(`/api/parcels/${parcelId}/crops`).set(auth(alice.token))
      .send({ plant_id: tomatoId, sow_date: '2026-04-01', expected_harvest_date: '2026-03-01' });
    expect(create.status).toBe(400);

    const update = await api.patch(`/api/crops/${cropId}`).set(auth(alice.token)).send({ actual_harvest_date: '2026-01-01' });
    expect(update.status).toBe(400);
  });

  test("another user can't access my crop", async () => {
    expect((await api.get(`/api/crops/${cropId}`).set(auth(bob.token))).status).toBe(404);
    expect((await api.get(`/api/parcels/${parcelId}/crops`).set(auth(bob.token))).status).toBe(404);
    expect((await api.post(`/api/parcels/${parcelId}/crops`).set(auth(bob.token)).send({ plant_id: tomatoId })).status).toBe(404);
    expect((await api.patch(`/api/crops/${cropId}`).set(auth(bob.token)).send({ comment: 'x' })).status).toBe(404);
    expect((await api.delete(`/api/crops/${cropId}`).set(auth(bob.token))).status).toBe(404);
  });

  test('a plant used by a crop cannot be deleted -> 409 RESOURCE_IN_USE', async () => {
    const res = await api.delete(`/api/plants/${tomatoId}`).set(auth(admin.token));
    expect(res.status).toBe(409);
    expect(res.body.code).toBe('RESOURCE_IN_USE');
  });

  test('deleting a garden deletes its parcels and crops', async () => {
    expect((await api.delete(`/api/gardens/${gardenId}`).set(auth(alice.token))).status).toBe(204);
    expect((await api.get(`/api/parcels/${parcelId}`).set(auth(alice.token))).status).toBe(404);
    const [crops] = await db.query('SELECT id FROM crop WHERE id = ?', [cropId]);
    expect(crops).toHaveLength(0);
  });
});

describe('plants (reference catalog)', () => {
  test('every user can read the seeded catalog', async () => {
    const res = await api.get('/api/plants').set(auth(alice.token));
    expect(res.status).toBe(200);
    expect(res.body.length).toBe(30);
    expect(res.body[0]).toHaveProperty('code');
  });

  test('filter by type and search', async () => {
    const herbs = await api.get('/api/plants?type=herb').set(auth(alice.token));
    expect(herbs.body.every((p) => p.type === 'herb')).toBe(true);

    const search = await api.get('/api/plants?search=tomat').set(auth(alice.token));
    expect(search.body.map((p) => p.code)).toContain('tomato');
  });

  test('a user cannot create a plant (403)', async () => {
    const res = await api.post('/api/plants').set(auth(alice.token)).send({ code: 'kale', name: 'Chou kale' });
    expect(res.status).toBe(403);
  });

  test('an admin can create, update and delete a plant', async () => {
    const created = await api.post('/api/plants').set(auth(admin.token)).send({ code: 'kale', name: 'Chou kale', type: 'vegetable' });
    expect(created.status).toBe(201);

    const updated = await api.patch(`/api/plants/${created.body.id}`).set(auth(admin.token)).send({ spacing_cm: 45 });
    expect(updated.body).toMatchObject({ code: 'kale', spacing_cm: 45 });

    const duplicate = await api.post('/api/plants').set(auth(admin.token)).send({ code: 'kale', name: 'Autre' });
    expect(duplicate.status).toBe(409);
    expect(duplicate.body.code).toBe('PLANT_CODE_ALREADY_USED');

    expect((await api.delete(`/api/plants/${created.body.id}`).set(auth(admin.token))).status).toBe(204);
  });

  test('invalid plant code -> 400', async () => {
    const res = await api.post('/api/plants').set(auth(admin.token)).send({ code: 'Big Tomato', name: 'X' });
    expect(res.status).toBe(400);
  });
});

describe('plant associations', () => {
  let ids;

  beforeAll(async () => {
    const [rows] = await db.query("SELECT id, code FROM plant WHERE code IN ('thyme', 'chives')");
    ids = Object.fromEntries(rows.map((r) => [r.code, r.id]));
  });

  test('seeded associations are readable and filterable, with plant codes', async () => {
    const [[tomato]] = await db.query("SELECT id FROM plant WHERE code = 'tomato'");
    const res = await api.get(`/api/plant-associations?plant_id=${tomato.id}`).set(auth(alice.token));
    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThan(0);
    expect(res.body.every((a) => a.plant_id_1 === tomato.id || a.plant_id_2 === tomato.id)).toBe(true);
    expect(res.body[0]).toHaveProperty('plant_code_1');
  });

  test('a pair is stored ordered and its reverse is a duplicate', async () => {
    const [high, low] = [Math.max(ids.thyme, ids.chives), Math.min(ids.thyme, ids.chives)];

    const created = await api.post('/api/plant-associations').set(auth(admin.token))
      .send({ plant_id_1: high, plant_id_2: low, relation_type: 'positive' });
    expect(created.status).toBe(201);
    expect(created.body.plant_id_1).toBe(low);
    expect(created.body.plant_id_2).toBe(high);

    const reverse = await api.post('/api/plant-associations').set(auth(admin.token))
      .send({ plant_id_1: low, plant_id_2: high, relation_type: 'negative' });
    expect(reverse.status).toBe(409);
    expect(reverse.body.code).toBe('ASSOCIATION_ALREADY_EXISTS');
  });

  test('a plant cannot be associated with itself', async () => {
    const res = await api.post('/api/plant-associations').set(auth(admin.token))
      .send({ plant_id_1: ids.thyme, plant_id_2: ids.thyme, relation_type: 'positive' });
    expect(res.status).toBe(400);
  });

  test('a user cannot modify associations (403)', async () => {
    const res = await api.post('/api/plant-associations').set(auth(alice.token))
      .send({ plant_id_1: ids.thyme, plant_id_2: ids.chives, relation_type: 'positive' });
    expect(res.status).toBe(403);
  });
});

describe('seed translations (frontend/assets/translations/en.json)', () => {
  // French comes from the database, other languages must translate every seeded plant
  const en = require('../../frontend/assets/translations/en.json');

  test('every seeded plant has an English name and description', async () => {
    const [plants] = await db.query("SELECT code FROM plant WHERE code <> 'kale'");
    const missing = plants.filter((p) => !en.plants?.[p.code]?.name || !en.plants?.[p.code]?.description);
    expect(missing.map((p) => p.code)).toEqual([]);
  });

  test('every seeded association comment is translated (key: codes sorted alphabetically)', async () => {
    const [rows] = await db.query(`
      SELECT p1.code AS c1, p2.code AS c2 FROM plant_association pa
      JOIN plant p1 ON p1.id = pa.plant_id_1
      JOIN plant p2 ON p2.id = pa.plant_id_2
      WHERE pa.comment IS NOT NULL`);
    const missing = rows.map((r) => [r.c1, r.c2].sort().join('__')).filter((key) => !en.plant_associations?.[key]);
    expect(missing).toEqual([]);
  });
});

describe('users', () => {
  test('GET /users/me', async () => {
    const res = await api.get('/api/users/me').set(auth(alice.token));
    expect(res.status).toBe(200);
    expect(res.body.email).toBe('alice@test.dev');
    expect(res.body.password_hash).toBeUndefined();
  });

  test('PATCH /users/me cannot change the role', async () => {
    const res = await api.patch('/api/users/me').set(auth(alice.token)).send({ username: 'Alice', role: 'admin' });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ username: 'Alice', role: 'user' });
  });

  test('PATCH /users/me with the email of another user -> 409', async () => {
    const res = await api.patch('/api/users/me').set(auth(alice.token)).send({ email: 'bob@test.dev' });
    expect(res.status).toBe(409);
    expect(res.body.code).toBe('EMAIL_ALREADY_USED');
  });

  test('change password', async () => {
    const wrong = await api.patch('/api/users/me/password').set(auth(alice.token))
      .send({ current_password: 'nope', new_password: 'newpassword123' });
    expect(wrong.status).toBe(400);
    expect(wrong.body.code).toBe('WRONG_PASSWORD');

    const ok = await api.patch('/api/users/me/password').set(auth(alice.token))
      .send({ current_password: 'password123', new_password: 'newpassword123' });
    expect(ok.status).toBe(204);

    const login = await api.post('/api/auth/login').send({ email: 'alice@test.dev', password: 'newpassword123' });
    expect(login.status).toBe(200);
  });

  test('only admins can list users, without password hashes', async () => {
    expect((await api.get('/api/users').set(auth(alice.token))).status).toBe(403);
    expect((await api.get(`/api/users/${bob.user.id}`).set(auth(alice.token))).status).toBe(403);

    const res = await api.get('/api/users').set(auth(admin.token));
    expect(res.status).toBe(200);
    expect(res.body.every((u) => u.password_hash === undefined)).toBe(true);
  });

  test('an admin can change the role of another user but not their own', async () => {
    const own = await api.patch(`/api/users/${admin.user.id}`).set(auth(admin.token)).send({ role: 'user' });
    expect(own.status).toBe(403);

    const other = await api.patch(`/api/users/${bob.user.id}`).set(auth(admin.token)).send({ role: 'admin' });
    expect(other.body.role).toBe('admin');
    // the role is read from the database : effective immediately with the same token
    expect((await api.get('/api/users').set(auth(bob.token))).status).toBe(200);
  });

  test('DELETE /users/me deletes the account and its gardens, the token stops working', async () => {
    const eve = await register('eve@test.dev');
    const garden = await api.post('/api/gardens').set(auth(eve.token)).send({ name: 'Jardin de Eve' });

    expect((await api.delete('/api/users/me').set(auth(eve.token))).status).toBe(204);

    const [gardens] = await db.query('SELECT id FROM garden WHERE id = ?', [garden.body.id]);
    expect(gardens).toHaveLength(0);

    const res = await api.get('/api/gardens').set(auth(eve.token));
    expect(res.status).toBe(401);
    expect(res.body.code).toBe('INVALID_TOKEN');
  });
});
