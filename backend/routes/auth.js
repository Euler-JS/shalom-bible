const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { protect } = require('../middleware/authMiddleware');

const signToken = (userId) =>
  jwt.sign({ id: userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
  });

// POST /api/auth/register
router.post('/register', async (req, res) => {
  try {
    const { email, password, name, language } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required.' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters.' });
    }

    const existing = await User.findOne({ email: email.toLowerCase() });
    if (existing) {
      return res.status(409).json({ message: 'Email already registered.' });
    }

    const user = await User.create({
      email,
      passwordHash: password,
      name: name || '',
      language: language || 'pt',
    });

    const token = signToken(user._id);
    res.status(201).json({ token, user: user.toPublicProfile() });
  } catch (err) {
    res.status(500).json({ message: 'Server error.', error: err.message });
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required.' });
    }

    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user || !user.passwordHash) {
      return res.status(401).json({ message: 'Invalid credentials.' });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Invalid credentials.' });
    }

    const token = signToken(user._id);
    res.json({ token, user: user.toPublicProfile() });
  } catch (err) {
    res.status(500).json({ message: 'Server error.', error: err.message });
  }
});

// POST /api/auth/google — Google OAuth token exchange
router.post('/google', async (req, res) => {
  try {
    const { googleId, email, name } = req.body;
    if (!googleId || !email) {
      return res.status(400).json({ message: 'googleId and email are required.' });
    }

    let user = await User.findOne({ $or: [{ googleId }, { email: email.toLowerCase() }] });

    if (!user) {
      user = await User.create({ googleId, email, name: name || '' });
    } else if (!user.googleId) {
      user.googleId = googleId;
      await user.save();
    }

    const token = signToken(user._id);
    res.json({ token, user: user.toPublicProfile() });
  } catch (err) {
    res.status(500).json({ message: 'Server error.', error: err.message });
  }
});

// GET /api/auth/me — get current user profile
router.get('/me', protect, async (req, res) => {
  res.json({ user: req.user.toPublicProfile() });
});

// PATCH /api/auth/language — update preferred language
router.patch('/language', protect, async (req, res) => {
  try {
    const { language } = req.body;
    if (!['pt', 'en'].includes(language)) {
      return res.status(400).json({ message: 'Language must be pt or en.' });
    }
    req.user.language = language;
    await req.user.save();
    res.json({ user: req.user.toPublicProfile() });
  } catch (err) {
    res.status(500).json({ message: 'Server error.', error: err.message });
  }
});

module.exports = router;
