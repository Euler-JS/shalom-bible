const express = require('express');
const router = express.Router();
const Sermon = require('../models/Sermon');
const User = require('../models/User');
const { protect } = require('../middleware/authMiddleware');

const FREE_SERMON_LIMIT = 5;

// GET /api/sermons — list user's sermons
router.get('/', protect, async (req, res) => {
  try {
    const { q, page = 1, limit = 20 } = req.query;
    const query = { userId: req.user._id };

    if (q) {
      query.$text = { $search: q };
    }

    const sermons = await Sermon.find(query)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit))
      .select('-__v');

    const total = await Sermon.countDocuments(query);

    res.json({ sermons, total, page: Number(page) });
  } catch (err) {
    res.status(500).json({ message: 'Server error.', error: err.message });
  }
});

// GET /api/sermons/:id — get single sermon
router.get('/:id', protect, async (req, res) => {
  try {
    const sermon = await Sermon.findOne({ _id: req.params.id, userId: req.user._id });
    if (!sermon) return res.status(404).json({ message: 'Sermon not found.' });
    res.json({ sermon });
  } catch (err) {
    res.status(500).json({ message: 'Server error.', error: err.message });
  }
});

// POST /api/sermons — save a new sermon
router.post('/', protect, async (req, res) => {
  try {
    const user = await User.findById(req.user._id);

    // Check free plan limits
    if (user.plan === 'free') {
      const sermonCount = await Sermon.countDocuments({ userId: user._id });
      if (sermonCount >= FREE_SERMON_LIMIT) {
        return res.status(403).json({
          message: 'Free plan limit reached (5 sermons). Upgrade to Premium for unlimited storage.',
          code: 'SERMON_LIMIT_REACHED',
        });
      }
    }

    const { title, basePassage, language, inputPrompt, content } = req.body;
    if (!title) {
      return res.status(400).json({ message: 'Title is required.' });
    }

    const sermon = await Sermon.create({
      userId: user._id,
      title,
      basePassage: basePassage || '',
      language: language || user.language || 'pt',
      inputPrompt: inputPrompt || '',
      content: content || {},
    });

    res.status(201).json({ sermon });
  } catch (err) {
    res.status(500).json({ message: 'Server error.', error: err.message });
  }
});

// PATCH /api/sermons/:id — update a sermon
router.patch('/:id', protect, async (req, res) => {
  try {
    const sermon = await Sermon.findOne({ _id: req.params.id, userId: req.user._id });
    if (!sermon) return res.status(404).json({ message: 'Sermon not found.' });

    const { title, basePassage, content } = req.body;
    if (title !== undefined) sermon.title = title;
    if (basePassage !== undefined) sermon.basePassage = basePassage;
    if (content !== undefined) sermon.content = content;

    await sermon.save();
    res.json({ sermon });
  } catch (err) {
    res.status(500).json({ message: 'Server error.', error: err.message });
  }
});

// DELETE /api/sermons/:id — delete a sermon
router.delete('/:id', protect, async (req, res) => {
  try {
    const sermon = await Sermon.findOneAndDelete({ _id: req.params.id, userId: req.user._id });
    if (!sermon) return res.status(404).json({ message: 'Sermon not found.' });
    res.json({ message: 'Sermon deleted.' });
  } catch (err) {
    res.status(500).json({ message: 'Server error.', error: err.message });
  }
});

module.exports = router;
