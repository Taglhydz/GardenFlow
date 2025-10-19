const User = require('../models/userModel');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

exports.register = async (req, res) => {
  // logique signup
  res.json({ message: 'register endpoint' });
};

exports.login = async (req, res) => {
  // logique login
  res.json({ message: 'login endpoint' });
};

exports.profile = async (req, res) => {
  // logique profile
  res.json({ message: 'profile endpoint' });
};
