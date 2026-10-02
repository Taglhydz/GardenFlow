const User     = require('../models/userModel');
const AppError = require('../utils/AppError');
const { hashPassword, comparePassword } = require('../utils/hash');
const { removePhoto, checkPhoto } = require('../utils/photoStorage');
const { computeLevel } = require('../services/levelService');
const { sendEmailChangeEmail } = require('../services/emailVerification');

/** Updates a user and turns a duplicate email into a clear error. */
const updateUser = async (id, data) => {
  try {
    return await User.update(id, data);
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') { throw AppError.conflict('EMAIL_ALREADY_USED', 'Email already in use'); }
    throw err;
  }
};

// ==================
// Current user (/me)
// ==================

/** GET /users/me */
exports.getMe = async (req, res) => {
  res.json(await User.findById(req.user.id));
};

/** PATCH /users/me - username, birthdate, avatar (not the role, nor the email). An avatar replaces the photo. */
exports.updateMe = async (req, res) => {
  const data = req.valid.body;
  const previous = await User.findById(req.user.id);
  if (data.avatar) data.photo = null;

  const user = await User.update(req.user.id, data);
  if (data.avatar) await removePhoto(previous.photo);

  res.json(user);
};

/**
 * PATCH /users/me/email - the new address is kept in pending_email and receives a link : it replaces the email
 * only once the link is opened (GET /auth/confirm-email), so a typo can't lock the account out.
 * Asked again : the previous link stops working. Needs the password, so not possible for an account created with Google.
 */
exports.changeEmail = async (req, res) => {
  const { email, current_password, lang } = req.valid.body;

  const hash = await User.findPasswordHash(req.user.id);

  // check password (an account created with Google has none : its email is the Google one)
  if (!hash) { throw new AppError(403, 'GOOGLE_ACCOUNT', 'The email of an account created with Google cannot be changed'); }
  if (!(await comparePassword(current_password, hash))) { throw AppError.badRequest('WRONG_PASSWORD', 'Current password is incorrect'); }

  const user = await User.findById(req.user.id);

  // check email
  if (email === user.email) { throw AppError.badRequest('SAME_EMAIL', 'This is already your email'); }
  if (await User.findByEmailWithPassword(email)) { throw AppError.conflict('EMAIL_ALREADY_USED', 'Email already in use'); }

  await sendEmailChangeEmail(user, email, lang);

  res.json(await User.findById(req.user.id));
};

/** DELETE /users/me/email - forgets the pending address, its link stops working */
exports.cancelEmailChange = async (req, res) => {
  await User.cancelEmailChange(req.user.id);

  res.json(await User.findById(req.user.id));
};

/** POST /users/me/photo (multipart, field `photo`) - replaces the photo and the avatar */
exports.uploadMyPhoto = async (req, res) => {
  // check photo sent
  if (!req.file) { throw AppError.badRequest('PHOTO_REQUIRED', 'Send the image in the `photo` field'); }

  await checkPhoto(req.file);

  const previous = await User.findById(req.user.id);
  const user = await User.update(req.user.id, { photo: req.file.filename, avatar: null });
  await removePhoto(previous.photo);

  res.json(user);
};

/** DELETE /users/me/photo - back to the first letter of the name */
exports.deleteMyPhoto = async (req, res) => {
  const previous = await User.findById(req.user.id);
  const user = await User.update(req.user.id, { photo: null });
  await removePhoto(previous.photo);

  res.json(user);
};

/** GET /users/me/level - seniority and mastery of the garden (see services/levelService.js) */
exports.getMyLevel = async (req, res) => {
  res.json(computeLevel(await User.levelStats(req.user.id)));
};

/** PATCH /users/me/password */
exports.changePassword = async (req, res) => {
  const { current_password, new_password } = req.valid.body;

  const hash = await User.findPasswordHash(req.user.id);

  // check current password (an account created with Google has none)
  if (!hash || !(await comparePassword(current_password, hash))) { throw AppError.badRequest('WRONG_PASSWORD', 'Current password is incorrect'); }

  await User.updatePassword(req.user.id, await hashPassword(new_password));

  res.status(204).end();
};

/** DELETE /users/me - deletes the account and all its gardens */
exports.deleteMe = async (req, res) => {
  const user = await User.findById(req.user.id);
  await User.delete(req.user.id);
  await removePhoto(user?.photo);

  res.status(204).end();
};

// ===========
// Admin only
// ===========

/** GET /users */
exports.getAllUsers = async (req, res) => {
  res.json(await User.findAll());
};

/** GET /users/:id */
exports.getUserById = async (req, res) => {
  const user = await User.findById(req.valid.params.id);

  // check user found
  if (!user) { throw AppError.notFound('User'); }

  res.json(user);
};

/** PATCH /users/:id - username, email, role */
exports.updateUserById = async (req, res) => {
  const { id } = req.valid.params;

  // an admin could lock themselves out by removing their own admin role
  if (id === req.user.id && req.valid.body.role !== undefined) { throw AppError.forbidden('You cannot change your own role'); }

  // check user found
  if (!(await User.findById(id))) { throw AppError.notFound('User'); }

  res.json(await updateUser(id, req.valid.body));
};

/** DELETE /users/:id */
exports.deleteUserById = async (req, res) => {
  const { id } = req.valid.params;

  if (id === req.user.id) { throw AppError.forbidden('Use DELETE /users/me to delete your own account'); }

  const user = await User.findById(id);

  // check user deleted
  if (!(await User.delete(id))) { throw AppError.notFound('User'); }

  await removePhoto(user?.photo);

  res.status(204).end();
};
