const User     = require('../models/userModel');
const AppError = require('../utils/AppError');
const { hashPassword, comparePassword } = require('../utils/hash');

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

/** PATCH /users/me - username, email, birthdate (not the role) */
exports.updateMe = async (req, res) => {
  res.json(await updateUser(req.user.id, req.valid.body));
};

/** PATCH /users/me/password */
exports.changePassword = async (req, res) => {
  const { current_password, new_password } = req.valid.body;

  const hash = await User.findPasswordHash(req.user.id);

  // check current password
  if (!(await comparePassword(current_password, hash))) { throw AppError.badRequest('WRONG_PASSWORD', 'Current password is incorrect'); }

  await User.updatePassword(req.user.id, await hashPassword(new_password));

  res.status(204).end();
};

/** DELETE /users/me - deletes the account and all its gardens */
exports.deleteMe = async (req, res) => {
  await User.delete(req.user.id);

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

  // check user deleted
  if (!(await User.delete(id))) { throw AppError.notFound('User'); }

  res.status(204).end();
};
