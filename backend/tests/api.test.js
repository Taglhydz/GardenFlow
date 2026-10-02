/**
 * Integration tests : real HTTP requests on the Express app and a real MySQL database.
 * ⚠️  The database DB_NAME_TEST is wiped and re-seeded before the tests.
 */
const request = require('supertest');
const app     = require('../src/app');
const db      = require('../src/database/db');
const { resetDatabase } = require('../scripts/db-reset');
const fs   = require('fs');
const path = require('path');
const { PHOTOS_DIR } = require('../src/utils/photoStorage');
const mailer = require('../src/utils/mailer');
const googleAuth = require('../src/services/googleAuth');

const api = request(app);

const PASSWORD = 'Password123!';

// the emails are not sent : each one is kept here (emptied before each test)
let sentEmails = [];
jest.spyOn(mailer, 'sendVerificationEmail').mockImplementation(async (mail) => { sentEmails.push(mail); });

// Google is not called : the "ID token" sent by the tests is the JSON of the Google profile, 'bad' is refused
jest.spyOn(googleAuth, 'verifyIdToken').mockImplementation(async (idToken) => {
  if (idToken === 'bad') throw new (require('../src/utils/AppError'))(401, 'INVALID_GOOGLE_TOKEN', 'Invalid Google token');
  return { emailVerified: true, name: null, ...JSON.parse(idToken) };
});
const googleLogin = (profile) => api.post('/api/auth/google').send({ id_token: JSON.stringify(profile) });
beforeEach(() => { sentEmails = []; });

/** Path of the verification link of the last email sent to `email` */
const verificationLink = (email) => {
  const url = sentEmails.filter((m) => m.to === email).at(-1)?.url;
  return url && url.slice(url.indexOf('/api/'));
};

/** Register, open the link of the email, log in */
const register = async (email, extra = {}) => {
  const res = await api.post('/api/auth/register').send({ username: 'tester', email, password: PASSWORD, ...extra });
  expect(res.status).toBe(201);
  expect((await api.get(verificationLink(email))).status).toBe(200);
  const login = await api.post('/api/auth/login').send({ email, password: PASSWORD });
  expect(login.status).toBe(200);
  return { token: login.body.token, user: login.body.user };
};

const auth = (token) => ({ Authorization: `Bearer ${token}` });

/** Rectangle shape (points relative to the parcel position) */
const rect = (w, h, x = 0, y = 0) => [{ x, y }, { x: x + w, y }, { x: x + w, y: y + h }, { x, y: y + h }];

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
      .send({ username: 'hacker', email: 'hacker@test.dev', password: PASSWORD, role: 'admin' });
    expect(res.status).toBe(201);
    expect(res.body.user.role).toBe('user');
    expect(res.body.user.password_hash).toBeUndefined();
  });

  test('register normalizes the email and keeps the birthdate as YYYY-MM-DD', async () => {
    const res = await api.post('/api/auth/register')
      .send({ username: ' Carol la Plus Belle ', email: '  Carol@Test.DEV ', password: PASSWORD, birthdate: '2000-01-01' });
    expect(res.status).toBe(201);
    expect(res.body.user.username).toBe('carol la plus belle'); // the app capitalizes it for display
    expect(res.body.user.email).toBe('carol@test.dev');
    expect(res.body.user.birthdate).toBe('2000-01-01');
  });

  test('register without birthdate works (optional)', async () => {
    const res = await api.post('/api/auth/register').send({ username: 'dave', email: 'dave@test.dev', password: PASSWORD });
    expect(res.status).toBe(201);
    expect(res.body.user.birthdate).toBeNull();
  });

  test('register with an existing email -> 409 EMAIL_ALREADY_USED', async () => {
    const res = await api.post('/api/auth/register').send({ username: 'alice2', email: 'ALICE@test.dev', password: PASSWORD });
    expect(res.status).toBe(409);
    expect(res.body.code).toBe('EMAIL_ALREADY_USED');
  });

  test('register with invalid data -> 400 VALIDATION_ERROR with details', async () => {
    const res = await api.post('/api/auth/register').send({ username: 'x', email: 'not-an-email', password: 'short' });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('VALIDATION_ERROR');
    expect(res.body.details.map((d) => d.field).sort()).toEqual(['email', 'password', 'username']);
  });

  test('register refuses a password without lowercase, uppercase, digit, symbol or 10 characters', async () => {
    for (const password of ['password123!', 'PASSWORD123!', 'Password!!!', 'Password123', 'Pass1!']) {
      const res = await api.post('/api/auth/register').send({ username: 'weak', email: 'weak@test.dev', password });
      expect(res.status).toBe(400);
      expect(res.body.details.map((d) => d.field)).toEqual(['password']);
    }
  });

  test('register with a birthdate in the future -> 400', async () => {
    const res = await api.post('/api/auth/register').send({ username: 'future', email: 'future@test.dev', password: PASSWORD, birthdate: '2999-01-01' });
    expect(res.status).toBe(400);
  });

  test('login OK', async () => {
    const res = await api.post('/api/auth/login').send({ email: 'alice@test.dev', password: PASSWORD });
    expect(res.status).toBe(200);
    expect(res.body.token).toBeDefined();
    expect(res.body.user.password_hash).toBeUndefined();
  });

  test('register gives no token and sends a verification email in the chosen language', async () => {
    const res = await api.post('/api/auth/register').send({ username: 'frank', email: 'frank@test.dev', password: PASSWORD, lang: 'en' });
    expect(res.status).toBe(201);
    expect(res.body.token).toBeUndefined();
    expect(res.body.user.email_verified_at).toBeNull();
    expect(sentEmails).toHaveLength(1);
    expect(sentEmails[0]).toMatchObject({ to: 'frank@test.dev', username: 'frank', lang: 'en' });
    expect(sentEmails[0].url).toMatch(/\/api\/auth\/verify-email\?token=[0-9a-f]{64}$/);
  });

  test('login is refused until the email is verified, the link then only shows that it is verified', async () => {
    await api.post('/api/auth/register').send({ username: 'grace', email: 'grace@test.dev', password: PASSWORD });

    const before = await api.post('/api/auth/login').send({ email: 'grace@test.dev', password: PASSWORD });
    expect(before.status).toBe(403);
    expect(before.body.code).toBe('EMAIL_NOT_VERIFIED');

    // a wrong password doesn't tell that the email is not verified
    const wrong = await api.post('/api/auth/login').send({ email: 'grace@test.dev', password: 'wrongpassword' });
    expect(wrong.body.code).toBe('INVALID_CREDENTIALS');

    const link  = verificationLink('grace@test.dev');
    const first = await api.get(link).set('Accept-Language', 'fr');
    expect(first.status).toBe(200);
    expect(first.type).toBe('text/html');
    expect(first.text).toContain('Email vérifié !');

    const again = await api.get(link).set('Accept-Language', 'en');
    expect(again.status).toBe(200);
    expect(again.text).toContain('Email already verified');

    const after = await api.post('/api/auth/login').send({ email: 'grace@test.dev', password: PASSWORD });
    expect(after.status).toBe(200);
    expect(after.body.user.email_verified_at).not.toBeNull();
  });

  test('an unknown or malformed verification link -> 400 page', async () => {
    expect((await api.get(`/api/auth/verify-email?token=${'a'.repeat(64)}`)).status).toBe(400);
    expect((await api.get('/api/auth/verify-email?token=nope')).status).toBe(400);
    expect((await api.get('/api/auth/verify-email')).status).toBe(400);
  });

  test('an expired link is refused, a new email can be asked and the old link stops working', async () => {
    await api.post('/api/auth/register').send({ username: 'henry', email: 'henry@test.dev', password: PASSWORD });
    const oldLink = verificationLink('henry@test.dev');

    // just sent : no new email for 1 minute
    const tooSoon = await api.post('/api/auth/resend-verification').send({ email: 'henry@test.dev' });
    expect(tooSoon.status).toBe(204);
    expect(sentEmails).toHaveLength(1);

    await db.query("UPDATE user SET verification_expires_at = NOW() - INTERVAL 1 HOUR WHERE email = 'henry@test.dev'");
    const expired = await api.get(oldLink);
    expect(expired.status).toBe(400);
    expect(expired.text).toContain('Lien expiré');

    expect((await api.post('/api/auth/resend-verification').send({ email: 'Henry@test.dev', lang: 'en' })).status).toBe(204);
    await new Promise((resolve) => setTimeout(resolve, 50)); // the email is sent after the answer
    expect(sentEmails).toHaveLength(2);
    expect(sentEmails[1].lang).toBe('en');

    expect((await api.get(oldLink)).status).toBe(400);
    expect((await api.get(verificationLink('henry@test.dev'))).status).toBe(200);
  });

  test('resend-verification says nothing about unknown or verified emails', async () => {
    const unknown  = await api.post('/api/auth/resend-verification').send({ email: 'nobody@test.dev' });
    const verified = await api.post('/api/auth/resend-verification').send({ email: 'alice@test.dev' });
    expect(unknown.status).toBe(204);
    expect(verified.status).toBe(204);
    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(sentEmails).toHaveLength(0);
  });

  test('Google : a new account is created, verified, without password ; the next time it logs in', async () => {
    const first = await googleLogin({ sub: 'g-jade', email: 'Jade@Gmail.com', name: 'Jade Martin' });
    expect(first.status).toBe(201);
    expect(first.body.created).toBe(true);
    expect(first.body.token).toBeDefined();
    expect(first.body.user).toMatchObject({ username: 'jade martin', email: 'jade@gmail.com', role: 'user' });
    expect(first.body.user.email_verified_at).not.toBeNull();
    expect(sentEmails).toHaveLength(0);

    // the token works
    expect((await api.get('/api/users/me').set(auth(first.body.token))).status).toBe(200);

    // same Google account, even with another email : same GardenFlow account
    const again = await googleLogin({ sub: 'g-jade', email: 'jade.new@gmail.com' });
    expect(again.status).toBe(200);
    expect(again.body.created).toBe(false);
    expect(again.body.user.id).toBe(first.body.user.id);

    // no password : the email + password login is refused, the email is taken
    const login = await api.post('/api/auth/login').send({ email: 'jade@gmail.com', password: PASSWORD });
    expect(login.body.code).toBe('INVALID_CREDENTIALS');
    const register = await api.post('/api/auth/register').send({ username: 'jade', email: 'jade@gmail.com', password: PASSWORD });
    expect(register.body.code).toBe('EMAIL_ALREADY_USED');
    const change = await api.patch('/api/users/me/password').set(auth(first.body.token))
      .send({ current_password: 'anything', new_password: 'NewPassword456?' });
    expect(change.body.code).toBe('WRONG_PASSWORD');
  });

  test('Google : a verified account with the same email is linked and keeps its password', async () => {
    const kim = await register('kim@test.dev');

    const res = await googleLogin({ sub: 'g-kim', email: 'kim@test.dev', name: 'Kim' });
    expect(res.status).toBe(200);
    expect(res.body.created).toBe(false);
    expect(res.body.user.id).toBe(kim.user.id);

    expect((await api.post('/api/auth/login').send({ email: 'kim@test.dev', password: PASSWORD })).status).toBe(200);
  });

  test('Google : an unverified account with the same email is verified and loses its password (maybe not its owner)', async () => {
    await api.post('/api/auth/register').send({ username: 'squatter', email: 'leo@test.dev', password: PASSWORD });

    const res = await googleLogin({ sub: 'g-leo', email: 'leo@test.dev', name: 'Leo' });
    expect(res.status).toBe(200);
    expect(res.body.user.email_verified_at).not.toBeNull();

    const login = await api.post('/api/auth/login').send({ email: 'leo@test.dev', password: PASSWORD });
    expect(login.body.code).toBe('INVALID_CREDENTIALS');
  });

  test('Google : invalid token, unverified Google email, missing token', async () => {
    const bad = await api.post('/api/auth/google').send({ id_token: 'bad' });
    expect(bad.status).toBe(401);
    expect(bad.body.code).toBe('INVALID_GOOGLE_TOKEN');

    const unverified = await googleLogin({ sub: 'g-mia', email: 'mia@test.dev', emailVerified: false });
    expect(unverified.status).toBe(401);
    expect(unverified.body.code).toBe('GOOGLE_EMAIL_NOT_VERIFIED');

    expect((await api.post('/api/auth/google').send({})).status).toBe(400);
  });

  test('Google : a short or missing name gives a username from the email', async () => {
    const res = await googleLogin({ sub: 'g-noname', email: 'noa.petit@test.dev', name: 'N' });
    expect(res.body.user.username).toBe('noa.petit');
  });

  test('wrong password and unknown email give the same error', async () => {
    const wrong   = await api.post('/api/auth/login').send({ email: 'alice@test.dev',   password: 'wrongpassword' });
    const unknown = await api.post('/api/auth/login').send({ email: 'unknown@test.dev', password: PASSWORD });
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

  test('the location gets a capital on each word', async () => {
    const res = await api.patch(`/api/gardens/${gardenId}`).set(auth(alice.token)).send({ location: 'saint-étienne, france' });
    expect(res.body.location).toBe('Saint-Étienne, France');
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

  test('create a parcel : shape stored as JSON, area computed, defaults applied', async () => {
    const res = await api.post(`/api/gardens/${gardenId}/parcels`).set(auth(alice.token))
      .send({ name: 'Carré 1', pos_x: '1.5', shape: rect(1.2, 2.5), soil_type: 'clay' });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ garden_id: gardenId, pos_x: 1.5, pos_y: 0, area_m2: 3, soil_type: 'clay', sunlight: 'medium' });
    expect(res.body.shape).toEqual(rect(1.2, 2.5));
    parcelId = res.body.id;
  });

  test('invalid enum -> 400', async () => {
    const res = await api.post(`/api/gardens/${gardenId}/parcels`).set(auth(alice.token)).send({ name: 'X', shape: rect(1, 1), soil_type: 'mud' });
    expect(res.status).toBe(400);
  });

  test("can't create a parcel in another user's garden", async () => {
    const res = await api.post(`/api/gardens/${gardenId}/parcels`).set(auth(bob.token)).send({ name: 'Intrus', shape: rect(1, 1) });
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

describe('plant calendar (periods) and family', () => {
  test('plants are returned with their family and all their periods', async () => {
    const res = await api.get('/api/plants?search=pinard').set(auth(alice.token));
    const spinach = res.body.find((p) => p.code === 'spinach');

    expect(spinach.family).toBe('amaranthaceae');
    expect(spinach.days_to_maturity).toBe(45);
    // sown in spring AND in autumn
    expect(spinach.periods.filter((p) => p.type === 'sow_outdoor')).toEqual([
      { type: 'sow_outdoor', start_month: 2, end_month: 4 },
      { type: 'sow_outdoor', start_month: 8, end_month: 10 },
    ]);
  });

  test('an admin creates a plant with periods, an update replaces them', async () => {
    const created = await api.post('/api/plants').set(auth(admin.token)).send({
      code: 'rocket', name: 'Roquette', family: 'brassicaceae',
      periods: [{ type: 'sow_outdoor', start_month: 3, end_month: 5 }, { type: 'sow_outdoor', start_month: 8, end_month: 9 }],
    });
    expect(created.status).toBe(201);
    expect(created.body.periods).toHaveLength(2);

    const updated = await api.patch(`/api/plants/${created.body.id}`).set(auth(admin.token))
      .send({ periods: [{ type: 'harvest', start_month: 11, end_month: 2 }] });
    expect(updated.body.periods).toEqual([{ type: 'harvest', start_month: 11, end_month: 2 }]);

    // an update without periods keeps them
    const renamed = await api.patch(`/api/plants/${created.body.id}`).set(auth(admin.token)).send({ name: 'Roquette cultivée' });
    expect(renamed.body.periods).toHaveLength(1);

    await api.delete(`/api/plants/${created.body.id}`).set(auth(admin.token));
  });

  test('invalid period -> 400, and nothing is created', async () => {
    const res = await api.post('/api/plants').set(auth(admin.token))
      .send({ code: 'bad_period', name: 'X', periods: [{ type: 'sow_outdoor', start_month: 13, end_month: 2 }] });
    expect(res.status).toBe(400);

    const search = await api.get('/api/plants?search=bad_period').set(auth(admin.token));
    expect(search.body).toHaveLength(0);
  });
});

describe('garden plan and suggestions', () => {
  let gardenId;
  let parcelA; // tomato is growing here
  let parcelB; // touches parcel A
  let parcelC; // far away
  let ids;

  beforeAll(async () => {
    const [rows] = await db.query("SELECT id, code FROM plant WHERE code IN ('tomato', 'basil', 'potato', 'eggplant')");
    ids = Object.fromEntries(rows.map((r) => [r.code, r.id]));

    const garden = await api.post('/api/gardens').set(auth(alice.token)).send({ name: 'Plan' });
    gardenId = garden.body.id;

    const create = (body) => api.post(`/api/gardens/${gardenId}/parcels`).set(auth(alice.token)).send(body);
    parcelA = (await create({ name: 'A', pos_x: 0, pos_y: 0, shape: rect(2, 1.5), soil_type: 'humus', sunlight: 'high' })).body;
    parcelB = (await create({ name: 'B', pos_x: 2, pos_y: 0, shape: rect(1, 1.5), soil_type: 'humus', sunlight: 'high' })).body;
    parcelC = (await create({ name: 'C', pos_x: 6, pos_y: 4, shape: rect(1, 1) })).body;

    await api.post(`/api/parcels/${parcelA.id}/crops`).set(auth(alice.token)).send({ plant_id: ids.tomato, sow_date: '2026-05-01' });
  });

  test('the area is computed from the shape, and recomputed when it changes', async () => {
    expect(parcelA.area_m2).toBe(3);

    const res = await api.patch(`/api/parcels/${parcelA.id}`).set(auth(alice.token)).send({ shape: rect(3, 1.5) });
    expect(res.body.area_m2).toBe(4.5);

    const back = await api.patch(`/api/parcels/${parcelA.id}`).set(auth(alice.token)).send({ shape: rect(2, 1.5) });
    expect(back.body.area_m2).toBe(3);
  });

  test('moving a parcel keeps its area', async () => {
    const res = await api.patch(`/api/parcels/${parcelC.id}`).set(auth(alice.token)).send({ pos_x: 7 });
    expect(res.body).toMatchObject({ pos_x: 7, area_m2: 1 });
  });

  test('GET /gardens/:id/crops returns the crops of every parcel, only for the owner', async () => {
    await api.post(`/api/parcels/${parcelC.id}/crops`).set(auth(alice.token)).send({ plant_id: ids.basil });

    const res = await api.get(`/api/gardens/${gardenId}/crops`).set(auth(alice.token));
    expect(res.status).toBe(200);
    expect(res.body.map((c) => c.parcel_id).sort()).toEqual([parcelA.id, parcelC.id].sort());

    expect((await api.get(`/api/gardens/${gardenId}/crops`).set(auth(bob.token))).status).toBe(404);
  });

  test('suggestions in the parcel : companions first, bad companions last', async () => {
    const res = await api.get(`/api/parcels/${parcelA.id}/suggestions?month=5`).set(auth(alice.token));
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ parcel_id: parcelA.id, month: 5 });

    const { suggestions } = res.body;
    const basil  = suggestions.find((s) => s.plant_id === ids.basil);
    const potato = suggestions.find((s) => s.plant_id === ids.potato);

    expect(basil.reasons.map((r) => r.code)).toContain('good_companion');
    expect(potato.reasons.map((r) => r.code)).toContain('bad_companion');
    expect(basil.score).toBeGreaterThan(potato.score);
    // sorted by score
    expect(suggestions.map((s) => s.score)).toEqual([...suggestions.map((s) => s.score)].sort((a, b) => b - a));
    // only plants that can be sown / planted in May
    expect(suggestions.every((s) => s.actions.length > 0)).toBe(true);
  });

  test('the neighbour parcel sees the tomato as a neighbour', async () => {
    const res = await api.get(`/api/parcels/${parcelB.id}/suggestions?month=5`).set(auth(alice.token));
    const basil = res.body.suggestions.find((s) => s.plant_id === ids.basil);
    expect(basil.reasons.map((r) => r.code)).toContain('good_neighbour');
  });

  test('crop rotation : eggplant after harvested tomatoes is penalized', async () => {
    const before = await api.get(`/api/parcels/${parcelB.id}/suggestions?month=5`).set(auth(alice.token));
    const eggplantBefore = before.body.suggestions.find((s) => s.plant_id === ids.eggplant);

    const lastYear = new Date(Date.now() - 200 * 24 * 3600 * 1000).toISOString().slice(0, 10);
    await api.post(`/api/parcels/${parcelB.id}/crops`).set(auth(alice.token))
      .send({ plant_id: ids.tomato, sow_date: lastYear, actual_harvest_date: lastYear });

    const after = await api.get(`/api/parcels/${parcelB.id}/suggestions?month=5`).set(auth(alice.token));
    const eggplantAfter = after.body.suggestions.find((s) => s.plant_id === ids.eggplant);

    expect(eggplantAfter.reasons.map((r) => r.code)).toContain('rotation_same_family');
    expect(eggplantAfter.score).toBeLessThan(eggplantBefore.score);
  });

  test('without month : the current month is used', async () => {
    const res = await api.get(`/api/parcels/${parcelA.id}/suggestions`).set(auth(alice.token));
    expect(res.body.month).toBe(new Date().getMonth() + 1);
  });

  test('invalid month -> 400, other user -> 404', async () => {
    expect((await api.get(`/api/parcels/${parcelA.id}/suggestions?month=13`).set(auth(alice.token))).status).toBe(400);
    expect((await api.get(`/api/parcels/${parcelA.id}/suggestions`).set(auth(bob.token))).status).toBe(404);
  });
});

describe('free shapes and zones', () => {
  let gardenId;
  let parcel; // L shape : 3 x 3 m without its top-right 2 x 2 m corner
  let zoneA;  // bottom band of the L
  let zoneB;  // left band of the L, touching zone A
  let ids;

  const lShape = [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 1, y: 2 }, { x: 3, y: 2 }, { x: 3, y: 3 }, { x: 0, y: 3 }];
  const createZone = (body, token = alice.token) => api.post(`/api/parcels/${parcel.id}/zones`).set(auth(token)).send(body);
  const suggestionsOf = async (zoneId, code) => {
    const res = await api.get(`/api/zones/${zoneId}/suggestions?month=5`).set(auth(alice.token));
    return res.body.suggestions.find((s) => s.plant_code === code);
  };
  const reasonCodes = (suggestion) => suggestion.reasons.map((r) => r.code);

  beforeAll(async () => {
    const [rows] = await db.query("SELECT id, code FROM plant WHERE code IN ('tomato', 'basil', 'potato', 'eggplant', 'squash')");
    ids = Object.fromEntries(rows.map((r) => [r.code, r.id]));

    gardenId = (await api.post('/api/gardens').set(auth(alice.token)).send({ name: 'Formes' })).body.id;
    parcel = (await api.post(`/api/gardens/${gardenId}/parcels`).set(auth(alice.token))
      .send({ name: 'En L', pos_x: 4, pos_y: 1, shape: lShape, soil_type: 'humus', sunlight: 'high' })).body;
  });

  test('a free shape parcel : area computed with the real shape', () => {
    expect(parcel.area_m2).toBe(5);
    expect(parcel.shape).toEqual(lShape);
  });

  test('a self-crossing shape is refused', async () => {
    const res = await api.post(`/api/gardens/${gardenId}/parcels`).set(auth(alice.token))
      .send({ name: 'Noeud', shape: [{ x: 0, y: 0 }, { x: 2, y: 2 }, { x: 2, y: 0 }, { x: 0, y: 2 }] });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('VALIDATION_ERROR');
  });

  test('zones inside the parcel, touching each other', async () => {
    const a = await createZone({ name: 'Bande du bas', shape: rect(3, 1, 0, 2) });
    expect(a.status).toBe(201);
    expect(a.body).toMatchObject({ parcel_id: parcel.id, area_m2: 3 });
    zoneA = a.body;

    const b = await createZone({ name: 'Bande de gauche', shape: rect(1, 2) });
    expect(b.status).toBe(201);
    zoneB = b.body;
  });

  test('the name of a zone is optional : no name = automatic name (null), clearing it brings it back', async () => {
    // accepted without name : only its place is refused (the L is full)
    const unnamed = await createZone({ shape: rect(1, 1, 1.5, 0.5) });
    expect(unnamed.body.code).toBe('ZONE_OUTSIDE_PARCEL');

    const renamed = await api.patch(`/api/zones/${zoneB.id}`).set(auth(alice.token)).send({ name: 'Mes tomates' });
    expect(renamed.body.name).toBe('Mes tomates');
    const cleared = await api.patch(`/api/zones/${zoneB.id}`).set(auth(alice.token)).send({ name: '  ' });
    expect(cleared.status).toBe(200);
    expect(cleared.body.name).toBeNull();
  });

  test('a zone outside the parcel (in the missing corner of the L) is refused', async () => {
    const res = await createZone({ name: 'Dehors', shape: rect(1, 1, 1.5, 0.5) });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('ZONE_OUTSIDE_PARCEL');
  });

  test('overlapping zones are refused, also when a zone is modified', async () => {
    const res = await createZone({ name: 'Chevauche', shape: rect(1, 1, 0.5, 2) });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('ZONES_OVERLAP');

    const update = await api.patch(`/api/zones/${zoneB.id}`).set(auth(alice.token)).send({ shape: rect(1, 2.5) });
    expect(update.status).toBe(400);
    expect(update.body.code).toBe('ZONES_OVERLAP');
  });

  test('a parcel shape that would leave a zone outside is refused, moving the parcel is fine', async () => {
    const shrink = await api.patch(`/api/parcels/${parcel.id}`).set(auth(alice.token)).send({ shape: rect(3, 2) });
    expect(shrink.status).toBe(409);
    expect(shrink.body.code).toBe('ZONES_OUTSIDE_PARCEL');

    const move = await api.patch(`/api/parcels/${parcel.id}`).set(auth(alice.token)).send({ pos_x: 5 });
    expect(move.status).toBe(200);
    // the zones are relative to the parcel : they moved with it, nothing to change
    const zones = await api.get(`/api/parcels/${parcel.id}/zones`).set(auth(alice.token));
    expect(zones.body.find((z) => z.id === zoneA.id).shape).toEqual(zoneA.shape);
  });

  test('GET /gardens/:id/zones, and another user cannot touch the zones', async () => {
    const res = await api.get(`/api/gardens/${gardenId}/zones`).set(auth(alice.token));
    expect(res.body.map((z) => z.id).sort()).toEqual([zoneA.id, zoneB.id].sort());

    expect((await api.get(`/api/gardens/${gardenId}/zones`).set(auth(bob.token))).status).toBe(404);
    expect((await api.get(`/api/zones/${zoneA.id}`).set(auth(bob.token))).status).toBe(404);
    expect((await api.patch(`/api/zones/${zoneA.id}`).set(auth(bob.token)).send({ name: 'x' })).status).toBe(404);
    expect((await api.delete(`/api/zones/${zoneA.id}`).set(auth(bob.token))).status).toBe(404);
    expect((await createZone({ name: 'x', shape: rect(0.5, 0.5, 0, 0) }, bob.token)).status).toBe(404);
    expect((await api.get(`/api/zones/${zoneA.id}/suggestions`).set(auth(bob.token))).status).toBe(404);
  });

  test('a crop can only use a zone of its own parcel', async () => {
    const other = (await api.post(`/api/gardens/${gardenId}/parcels`).set(auth(alice.token))
      .send({ name: 'Autre', pos_x: 20, shape: rect(1, 1) })).body;

    const wrong = await api.post(`/api/parcels/${other.id}/crops`).set(auth(alice.token)).send({ plant_id: ids.tomato, zone_id: zoneA.id });
    expect(wrong.status).toBe(400);
    expect(wrong.body.code).toBe('INVALID_ZONE');

    const ok = await api.post(`/api/parcels/${parcel.id}/crops`).set(auth(alice.token)).send({ plant_id: ids.tomato, zone_id: zoneA.id });
    expect(ok.status).toBe(201);
    expect(ok.body.zone_id).toBe(zoneA.id);
  });

  test('zone suggestions : companions in the zone count more than in the rest of the parcel', async () => {
    // tomato is in zone A
    const basilA = await suggestionsOf(zoneA.id, 'basil');
    const basilB = await suggestionsOf(zoneB.id, 'basil');

    expect(reasonCodes(basilA)).toContain('good_companion');
    expect(reasonCodes(basilB)).toContain('good_in_parcel');
    expect(basilA.score).toBeGreaterThan(basilB.score);
  });

  test('zone suggestions : crop rotation uses the history of the zone', async () => {
    const lastYear = new Date(Date.now() - 200 * 24 * 3600 * 1000).toISOString().slice(0, 10);
    await api.post(`/api/parcels/${parcel.id}/crops`).set(auth(alice.token))
      .send({ plant_id: ids.potato, zone_id: zoneB.id, sow_date: lastYear, actual_harvest_date: lastYear });

    expect(reasonCodes(await suggestionsOf(zoneB.id, 'eggplant'))).toContain('rotation_same_family');
    expect(reasonCodes(await suggestionsOf(zoneA.id, 'eggplant'))).not.toContain('rotation_same_family');
  });

  test('zone suggestions : how many plants fit, and zones too small for a plant', async () => {
    const tomato = await suggestionsOf(zoneA.id, 'tomato'); // 3 m², 50 cm spacing
    expect(tomato.reasons.find((r) => r.code === 'capacity').params).toEqual({ count: 12 });

    const mini = (await api.post(`/api/gardens/${gardenId}/parcels`).set(auth(alice.token))
      .send({ name: 'Mini', pos_x: 30, shape: rect(0.3, 0.3) })).body;
    const tiny = (await api.post(`/api/parcels/${mini.id}/zones`).set(auth(alice.token))
      .send({ name: 'Petit coin', shape: rect(0.3, 0.3) })).body;

    const squash = await suggestionsOf(tiny.id, 'squash'); // 1.5 m spacing
    expect(reasonCodes(squash)).toContain('too_small');
  });

  test('deleting a zone keeps its crops in the parcel', async () => {
    expect((await api.delete(`/api/zones/${zoneA.id}`).set(auth(alice.token))).status).toBe(204);
    const [crops] = await db.query('SELECT zone_id FROM crop WHERE parcel_id = ? AND plant_id = ?', [parcel.id, ids.tomato]);
    expect(crops).toEqual([{ zone_id: null }]);
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

  test('every botanical family of the seed is translated in every language', async () => {
    const fr = require('../../frontend/assets/translations/fr.json');
    const [families] = await db.query('SELECT DISTINCT family FROM plant WHERE family IS NOT NULL');

    for (const translations of [fr, en]) {
      const missing = families.filter((f) => !translations[`plant_family_${f.family}`]);
      expect(missing.map((f) => f.family)).toEqual([]);
    }
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

describe('plant colors', () => {
  let tomato;

  beforeAll(async () => {
    const res = await api.get('/api/plants?search=tomat').set(auth(alice.token));
    tomato = res.body.find((p) => p.code === 'tomato');
  });

  test('a user chooses a color, changes it and goes back to the automatic one', async () => {
    expect((await api.get('/api/users/me/plant-colors').set(auth(alice.token))).body).toEqual([]);

    const set = await api.put(`/api/users/me/plant-colors/${tomato.id}`).set(auth(alice.token)).send({ hue: 10 });
    expect(set.status).toBe(200);
    expect(set.body).toEqual({ plant_id: tomato.id, hue: 10 });

    await api.put(`/api/users/me/plant-colors/${tomato.id}`).set(auth(alice.token)).send({ hue: 200 });
    expect((await api.get('/api/users/me/plant-colors').set(auth(alice.token))).body).toEqual([{ plant_id: tomato.id, hue: 200 }]);

    expect((await api.delete(`/api/users/me/plant-colors/${tomato.id}`).set(auth(alice.token))).status).toBe(204);
    expect((await api.get('/api/users/me/plant-colors').set(auth(alice.token))).body).toEqual([]);
    expect((await api.delete(`/api/users/me/plant-colors/${tomato.id}`).set(auth(alice.token))).status).toBe(404);
  });

  test('the colors of a user are only his', async () => {
    await api.put(`/api/users/me/plant-colors/${tomato.id}`).set(auth(bob.token)).send({ hue: 90 });
    expect((await api.get('/api/users/me/plant-colors').set(auth(alice.token))).body).toEqual([]);
  });

  test('invalid hue -> 400, unknown plant -> 404', async () => {
    expect((await api.put(`/api/users/me/plant-colors/${tomato.id}`).set(auth(alice.token)).send({ hue: 360 })).status).toBe(400);
    expect((await api.put('/api/users/me/plant-colors/99999').set(auth(alice.token)).send({ hue: 10 })).status).toBe(404);
  });
});

describe('profile picture and level', () => {
  // smallest valid PNG (1 x 1 px)
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', 'base64');
  const photoFile = (name) => path.join(PHOTOS_DIR, name);

  test('choose a plant avatar, an unknown one is refused', async () => {
    const res = await api.patch('/api/users/me').set(auth(bob.token)).send({ avatar: 'tomato' });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ avatar: 'tomato', photo: null });

    expect((await api.patch('/api/users/me').set(auth(bob.token)).send({ avatar: 'dragon' })).status).toBe(400);
  });

  test('upload a photo : it replaces the avatar, is served, and the old file is deleted when replaced', async () => {
    const first = await api.post('/api/users/me/photo').set(auth(bob.token)).attach('photo', png, { filename: 'me.png', contentType: 'image/png' });
    expect(first.status).toBe(200);
    expect(first.body.avatar).toBeNull();
    expect(first.body.photo).toMatch(new RegExp(`^${bob.user.id}-.+\\.png$`));
    expect(fs.existsSync(photoFile(first.body.photo))).toBe(true);

    const served = await api.get(`/api/uploads/photos/${first.body.photo}`);
    expect(served.status).toBe(200);
    expect(served.headers['content-type']).toBe('image/png');

    const second = await api.post('/api/users/me/photo').set(auth(bob.token)).attach('photo', png, { filename: 'me.png', contentType: 'image/png' });
    expect(second.body.photo).not.toBe(first.body.photo);
    expect(fs.existsSync(photoFile(first.body.photo))).toBe(false);

    // an avatar replaces the photo and deletes it
    const avatar = await api.patch('/api/users/me').set(auth(bob.token)).send({ avatar: 'carrot' });
    expect(avatar.body).toMatchObject({ avatar: 'carrot', photo: null });
    expect(fs.existsSync(photoFile(second.body.photo))).toBe(false);
  });

  test('a file that is not an image is refused, even with an image type', async () => {
    const res = await api.post('/api/users/me/photo').set(auth(bob.token))
      .attach('photo', Buffer.from('<script>alert(1)</script>'), { filename: 'me.png', contentType: 'image/png' });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('INVALID_IMAGE');

    const gif = await api.post('/api/users/me/photo').set(auth(bob.token)).attach('photo', png, { filename: 'me.gif', contentType: 'image/gif' });
    expect(gif.body.code).toBe('INVALID_IMAGE');

    const none = await api.post('/api/users/me/photo').set(auth(bob.token)).field('name', 'x');
    expect(none.body.code).toBe('PHOTO_REQUIRED');
  });

  test('remove the photo', async () => {
    const up = await api.post('/api/users/me/photo').set(auth(bob.token)).attach('photo', png, { filename: 'me.png', contentType: 'image/png' });
    const res = await api.delete('/api/users/me/photo').set(auth(bob.token));
    expect(res.status).toBe(200);
    expect(res.body.photo).toBeNull();
    expect(fs.existsSync(photoFile(up.body.photo))).toBe(false);
    expect((await api.get(`/api/uploads/photos/${up.body.photo}`)).status).toBe(404);
  });

  test('level : computed from the crops of all my gardens', async () => {
    const before = await api.get('/api/users/me/level').set(auth(alice.token));
    expect(before.status).toBe(200);
    expect(before.body).toHaveProperty('rank');
    expect(before.body.stats.planted).toBeGreaterThan(0); // alice planted crops in the tests above

    const fresh = await register('newbie@test.dev');
    const level = await api.get('/api/users/me/level').set(auth(fresh.token));
    expect(level.body).toMatchObject({ rank: 'seed', points: 0, next_rank: 'sprout' });
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
    expect(res.body).toMatchObject({ username: 'alice', role: 'user' });
  });

  test('PATCH /users/me with the email of another user -> 409', async () => {
    const res = await api.patch('/api/users/me').set(auth(alice.token)).send({ email: 'bob@test.dev' });
    expect(res.status).toBe(409);
    expect(res.body.code).toBe('EMAIL_ALREADY_USED');
  });

  test('PATCH /users/me with a new email : it must be verified again before the next login', async () => {
    const ivy = await register('ivy@test.dev');

    const res = await api.patch('/api/users/me').set(auth(ivy.token)).send({ email: 'ivy2@test.dev', lang: 'en' });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ email: 'ivy2@test.dev', email_verified_at: null });
    expect(sentEmails.at(-1)).toMatchObject({ to: 'ivy2@test.dev', lang: 'en' });

    // still logged in, but the next login waits for the new link
    expect((await api.get('/api/users/me').set(auth(ivy.token))).status).toBe(200);
    expect((await api.post('/api/auth/login').send({ email: 'ivy2@test.dev', password: PASSWORD })).status).toBe(403);
    expect((await api.get(verificationLink('ivy2@test.dev'))).status).toBe(200);
    expect((await api.post('/api/auth/login').send({ email: 'ivy2@test.dev', password: PASSWORD })).status).toBe(200);

    // same email or other fields : nothing sent
    sentEmails = [];
    await api.patch('/api/users/me').set(auth(ivy.token)).send({ email: 'IVY2@test.dev', username: 'ivy' });
    expect(sentEmails).toHaveLength(0);
  });

  test('change password', async () => {
    const wrong = await api.patch('/api/users/me/password').set(auth(alice.token))
      .send({ current_password: 'nope', new_password: 'NewPassword456?' });
    expect(wrong.status).toBe(400);
    expect(wrong.body.code).toBe('WRONG_PASSWORD');

    const ok = await api.patch('/api/users/me/password').set(auth(alice.token))
      .send({ current_password: PASSWORD, new_password: 'NewPassword456?' });
    expect(ok.status).toBe(204);

    const login = await api.post('/api/auth/login').send({ email: 'alice@test.dev', password: 'NewPassword456?' });
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
