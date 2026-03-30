const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: [true, 'Email is required'],
      unique: true,
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, 'Invalid email format'],
    },
    passwordHash: {
      type: String,
      required: function () {
        return !this.googleId;
      },
    },
    name: {
      type: String,
      trim: true,
      default: '',
    },
    googleId: {
      type: String,
      default: null,
    },
    plan: {
      type: String,
      enum: ['free', 'premium'],
      default: 'free',
    },
    language: {
      type: String,
      enum: ['pt', 'en'],
      default: 'pt',
    },
    usageThisWeek: {
      scenarioSearch: { type: Number, default: 0 },
      weekStartDate: { type: Date, default: Date.now },
    },
    usageThisMonth: {
      sermonGenerator: { type: Number, default: 0 },
      monthStartDate: { type: Date, default: Date.now },
    },
  },
  { timestamps: true }
);

// Hash password before saving
userSchema.pre('save', async function (next) {
  if (!this.isModified('passwordHash')) return next();
  const salt = await bcrypt.genSalt(12);
  this.passwordHash = await bcrypt.hash(this.passwordHash, salt);
  next();
});

// Compare password method
userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.passwordHash);
};

// Reset weekly usage if week has passed
userSchema.methods.resetWeeklyUsageIfNeeded = function () {
  const now = new Date();
  const weekStart = new Date(this.usageThisWeek.weekStartDate);
  const diffDays = (now - weekStart) / (1000 * 60 * 60 * 24);
  if (diffDays >= 7) {
    this.usageThisWeek.scenarioSearch = 0;
    this.usageThisWeek.weekStartDate = now;
  }
};

// Reset monthly usage if month has passed
userSchema.methods.resetMonthlyUsageIfNeeded = function () {
  const now = new Date();
  const monthStart = new Date(this.usageThisMonth.monthStartDate);
  if (
    now.getMonth() !== monthStart.getMonth() ||
    now.getFullYear() !== monthStart.getFullYear()
  ) {
    this.usageThisMonth.sermonGenerator = 0;
    this.usageThisMonth.monthStartDate = now;
  }
};

// Return public profile (no password)
userSchema.methods.toPublicProfile = function () {
  return {
    id: this._id,
    email: this.email,
    name: this.name,
    plan: this.plan,
    language: this.language,
    usageThisWeek: { scenarioSearch: this.usageThisWeek.scenarioSearch },
    usageThisMonth: { sermonGenerator: this.usageThisMonth.sermonGenerator },
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('User', userSchema);
