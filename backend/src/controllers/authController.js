const User   = require('../models/userModel');
const bcrypt = require('bcrypt');
const jwt    = require('jsonwebtoken');

exports.register = async (req, res) => {
  try {
    const { username, email, password, birthdate, role } = req.body;

	// check required fields
    if (!username || !email || !password || !birthdate) { return res.status(400).json({ message: 'Missing required fields' }); }

    const existingUser = await User.getByEmail(email);

	// check email
    if (existingUser) { return res.status(409).json({ message: 'Email already in use' }); }

    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = await User.create({
      username,
      email,
      password: hashedPassword,
      birthdate,
      role: role || 'user',
    });

    res.status(201).json({ id: newUser.id, username, email, birthdate, role: role || 'user' });

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

	// check required fields
    if (!email || !password) { return res.status(400).json({ message: 'Missing email or password' }); }

    const user = await User.getByEmail(email);

	// check user
    if (!user) { return res.status(401).json({ message: 'Invalid credentials' }); }

    const valid = await bcrypt.compare(password, user.password);

	// check password
    if (!valid) { return res.status(401).json({ message: 'Invalid credentials' }); }

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({ token, user: { id: user.id, username: user.username, email: user.email, birthdate: user.birthdate, role: user.role } });

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

exports.profile = async (req, res) => {
  try {
    const userId = req.user?.id;

	// check userId
    if (!userId) { return res.status(401).json({ message: 'Unauthorized' }); }

    const user = await User.getById(userId);

	// check user found
    if (!user) { return res.status(404).json({ message: 'User not found' }); }

    res.json({ id: user.id, username: user.username, email: user.email, birthdate: user.birthdate, role: user.role });

  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};
