require('dotenv').config();
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const connectDB = require('./config/db');

const app = express();

// Connect to MongoDB
connectDB();

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Global rate limiter
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 200,
  message: { message: 'Too many requests. Please try again later.' },
});
app.use('/api/', limiter);

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/sermons', require('./routes/sermons'));
app.use('/api/usage', require('./routes/usage'));

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok', service: 'shalom-bible-api' }));

// 404 handler
app.use((req, res) => res.status(404).json({ message: 'Route not found.' }));

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ message: 'Internal server error.' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Shalom Bible API running on port ${PORT} [${process.env.NODE_ENV || 'development'}]`);
});
