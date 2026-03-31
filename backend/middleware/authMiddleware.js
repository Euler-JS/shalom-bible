const jwt = require('jsonwebtoken');
const User = require('../models/User');

const resolveToken = (req) => {
  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith('Bearer ')
  ) {
    return req.headers.authorization.split(' ')[1];
  }
  return null;
};

const loadUserFromToken = async (token) => {
  const decoded = jwt.verify(token, process.env.JWT_SECRET);
  return User.findById(decoded.id).select('-passwordHash');
};

const protect = async (req, res, next) => {
  const token = resolveToken(req);
  if (!token) {
    return res.status(401).json({ message: 'Not authorized. No token.' });
  }

  try {
    req.user = await loadUserFromToken(token);
    if (!req.user) {
      return res.status(401).json({ message: 'User not found.' });
    }
    next();
  } catch (error) {
    return res.status(401).json({ message: 'Token invalid or expired.' });
  }
};

const optionalProtect = async (req, res, next) => {
  const token = resolveToken(req);
  if (!token) {
    return next();
  }

  try {
    req.user = await loadUserFromToken(token);
  } catch (_) {
    req.user = null;
  }

  return next();
};

module.exports = { protect, optionalProtect };
