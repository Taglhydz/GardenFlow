const User = require('../models/userModel');

exports.getAllUsers = async (req, res) => {
  try {
    const users = await User.getAll();

    res.status(200).json(users);

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la récupération des utilisateurs', details: err.message });
  }
};

exports.getUserById = async (req, res) => {
  const { id } = req.params;

  try {
    const user = await User.getById(id);

    // check user found
    if (!user) { return res.status(404).json({ error: 'Utilisateur non trouvé' }); }

    res.status(200).json(user);

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la récupération de l’utilisateur', details: err.message });
  }
};

exports.createUser = async (req, res) => {
  const { username, email, password, birthdate, role } = req.body;

  // check required fields
  if (!username || !email || !password) { return res.status(400).json({ error: 'username, email et password sont requis' }); }

  try {
    const existingUser = await User.getByEmail(email);

    // check email
    if (existingUser) { return res.status(409).json({ error: 'Email déjà utilisé' }); }

    const bcrypt = require('bcrypt');
    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = { username, email, password: hashedPassword, birthdate, role };
    const created = await User.create(newUser);

    res.status(201).json({ message: 'Utilisateur créé', user: created });

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la création de l’utilisateur', details: err.message });
  }
};

exports.updateUser = async (req, res) => {
  const { id } = req.params;
  const { username, email, password, birthdate, role } = req.body;

  try {
    const user = await User.getById(id);

    // check user found
    if (!user) { return res.status(404).json({ error: 'Utilisateur non trouvé' }); }

    let updatedPassword = user.password;

    if (password) {
      const bcrypt = require('bcrypt');
      updatedPassword = await bcrypt.hash(password, 10);
    }

    const updatedUser = { username, email, password: updatedPassword, birthdate, role };
    const result = await User.update(id, updatedUser);

    // check no modification made
    if (result.affectedRows === 0) {  return res.status(404).json({ error: 'Utilisateur non trouvé ou supprimé' }); }

    res.status(200).json({ message: 'Utilisateur mis à jour avec succès' });

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la mise à jour de l’utilisateur', details: err.message });
  }
};

exports.deleteUser = async (req, res) => {
  const { id } = req.params;

  try {
    const result = await User.softDelete(id);

    // check user deleted
    if (result.affectedRows === 0) { return res.status(404).json({ error: 'Utilisateur non trouvé ou déjà supprimé' }); }

    res.status(200).json({ message: 'Utilisateur supprimé (soft delete) avec succès' });

  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la suppression de l’utilisateur', details: err.message });
  }
};
