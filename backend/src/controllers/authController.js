const User     = require('../models/userModel');
const AppError = require('../utils/AppError');
const { hashPassword, comparePassword } = require('../utils/hash');
const { signToken } = require('../middlewares/authMiddleware');

// Compared when the email doesn't exist, so that a login takes the same time
// whether the account exists or not (prevents guessing registered emails).
const DUMMY_HASH = '$2b$10$VYNkVe19xl3i3r5naF7iK.aM50HvSOsP0vYjik/f7pR0LjWQKxQc.';

/** POST /auth/register - the role is always 'user' (admins are promoted with scripts/set-role.js) */
exports.register = async (req, res) => {
  const { username, email, password, birthdate } = req.valid.body;

  // check email
  if (await User.findByEmailWithPassword(email)) { throw AppError.conflict('EMAIL_ALREADY_USED', 'Email already in use'); }

  let user;
  try {
    user = await User.create({ username, email, passwordHash: await hashPassword(password), birthdate });
  } catch (err) {
    // two simultaneous registrations with the same email
    if (err.code === 'ER_DUP_ENTRY') { throw AppError.conflict('EMAIL_ALREADY_USED', 'Email already in use'); }
    throw err;
  }

  res.status(201).json({ token: signToken(user), user });
};

/** POST /auth/login */
exports.login = async (req, res) => {
  const { email, password } = req.valid.body;

  const found = await User.findByEmailWithPassword(email);
  const valid = await comparePassword(password, found?.password_hash ?? DUMMY_HASH);

  // same error for unknown email and wrong password
  if (!found || !valid) { throw AppError.unauthorized('INVALID_CREDENTIALS', 'Invalid email or password'); }

  const { password_hash, ...user } = found;

  res.json({ token: signToken(user), user });
};
