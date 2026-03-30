const express = require('express');
const router = express.Router();
const User = require('../models/User');
const { protect } = require('../middleware/authMiddleware');

const FREE_LIMITS = {
  scenarioSearch: 3,   // per week
  sermonGenerator: 2,  // per month
};

// GET /api/usage — get current usage stats
router.get('/', protect, async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    user.resetWeeklyUsageIfNeeded();
    user.resetMonthlyUsageIfNeeded();
    await user.save();

    res.json({
      plan: user.plan,
      usage: {
        scenarioSearch: {
          used: user.usageThisWeek.scenarioSearch,
          limit: user.plan === 'free' ? FREE_LIMITS.scenarioSearch : null,
          period: 'week',
        },
        sermonGenerator: {
          used: user.usageThisMonth.sermonGenerator,
          limit: user.plan === 'free' ? FREE_LIMITS.sermonGenerator : null,
          period: 'month',
        },
      },
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error.', error: err.message });
  }
});

// POST /api/usage/increment — increment a usage counter
// Called by Flutter before/after an AI operation
router.post('/increment', protect, async (req, res) => {
  try {
    const { feature } = req.body;
    const user = await User.findById(req.user._id);
    user.resetWeeklyUsageIfNeeded();
    user.resetMonthlyUsageIfNeeded();

    if (feature === 'scenarioSearch') {
      if (
        user.plan === 'free' &&
        user.usageThisWeek.scenarioSearch >= FREE_LIMITS.scenarioSearch
      ) {
        return res.status(403).json({
          message: 'Weekly limit reached (3 searches). Upgrade to Premium.',
          code: 'SCENARIO_LIMIT_REACHED',
        });
      }
      user.usageThisWeek.scenarioSearch += 1;
    } else if (feature === 'sermonGenerator') {
      if (
        user.plan === 'free' &&
        user.usageThisMonth.sermonGenerator >= FREE_LIMITS.sermonGenerator
      ) {
        return res.status(403).json({
          message: 'Monthly limit reached (2 outlines). Upgrade to Premium.',
          code: 'SERMON_GEN_LIMIT_REACHED',
        });
      }
      user.usageThisMonth.sermonGenerator += 1;
    } else {
      return res.status(400).json({ message: 'Unknown feature.' });
    }

    await user.save();
    res.json({ success: true, user: user.toPublicProfile() });
  } catch (err) {
    res.status(500).json({ message: 'Server error.', error: err.message });
  }
});

module.exports = router;
