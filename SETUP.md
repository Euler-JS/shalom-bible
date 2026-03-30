# Shalom Bible — Setup Guide

## Project Structure

```
shalom-bible/
├── backend/          Node.js + Express API
├── flutter_app/      Flutter mobile app
└── scripts/          Database creation scripts
```

---

## 1. Backend Setup

```bash
cd backend
cp .env.example .env
# Edit .env with your values:
#   MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/shalom_bible
#   JWT_SECRET=your_secret_here
#   PORT=3000

npm install
npm run dev   # development (nodemon)
npm start     # production
```

### API Endpoints

| Method | Route | Description |
|--------|-------|-------------|
| POST | /api/auth/register | Create account |
| POST | /api/auth/login | Login |
| GET | /api/auth/me | Current user profile |
| POST | /api/auth/google | Google OAuth |
| GET | /api/sermons | List sermons |
| POST | /api/sermons | Save sermon |
| DELETE | /api/sermons/:id | Delete sermon |
| POST | /api/usage/increment | Increment usage counter |
| GET | /api/usage | Get usage stats |

---

## 2. Bible Database Setup

### Get Bible Data

1. Run the schema creator:
```bash
python3 scripts/create_bible_db.py
```

2. Download Bible data from:
   - https://github.com/scrollmapper/bible_databases (open source, multiple translations)

3. Convert and import into the created `.db` files using the `import_from_json()` function.

4. Place files in:
   ```
   flutter_app/assets/bible/arc.db
   flutter_app/assets/bible/kjv.db
   flutter_app/assets/strongs/strongs_hebrew.db
   flutter_app/assets/strongs/strongs_greek.db
   ```

### Expected Schema

**verses table** (arc.db / kjv.db):
```sql
CREATE TABLE verses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book TEXT NOT NULL,        -- "Gênesis" or "Genesis"
  book_number INTEGER NOT NULL,  -- 1 = Genesis, 66 = Revelation
  chapter INTEGER NOT NULL,
  verse INTEGER NOT NULL,
  text TEXT NOT NULL
);
```

**strongs table** (strongs_hebrew.db / strongs_greek.db):
```sql
CREATE TABLE strongs (
  number TEXT PRIMARY KEY,    -- "H1", "G1" etc.
  original_word TEXT,
  transliteration TEXT,
  meaning TEXT,
  language TEXT               -- "hebrew" or "greek"
);
```

---

## 3. Flutter App Setup

### Install Fonts

Download and place in `flutter_app/assets/fonts/`:
- Merriweather: https://fonts.google.com/specimen/Merriweather
  - Merriweather-Regular.ttf
  - Merriweather-Bold.ttf
  - Merriweather-Italic.ttf

### Configure the App

1. Install dependencies:
```bash
cd flutter_app
flutter pub get
```

2. Open the app and go to **Settings** (gear icon)

3. Enter your **OpenAI API Key** (from platform.openai.com)

4. Configure the **Backend URL** in:
   `lib/core/constants/app_constants.dart`
   ```dart
   static const String backendBaseUrl = 'https://your-backend.com/api';
   ```

### Run on Device

```bash
flutter run                    # debug mode
flutter run --release          # release mode
flutter build apk --release    # Android APK
flutter build ios --release    # iOS
```

---

## 4. Free Plan Limits

| Feature | Free | Premium |
|---------|------|---------|
| Bible Reading | Unlimited | Unlimited |
| Strong's (offline) | Unlimited | Unlimited |
| Scenario Search | 3/week | Unlimited |
| Sermon Generator | 2/month | Unlimited |
| Sermon Library | 5 saved | Unlimited |
| AI Model | GPT-4.1-mini | GPT-4.1 |

---

## 5. Environment Variables

### Backend (.env)
```
PORT=3000
MONGODB_URI=mongodb+srv://...
JWT_SECRET=your_jwt_secret
JWT_EXPIRES_IN=30d
NODE_ENV=production
```

### Flutter (set in Settings screen at runtime)
- **OpenAI API Key** — stored securely in flutter_secure_storage
- These are never hardcoded in the app

---

## 6. Architecture

```
Flutter App
├── Riverpod (state management)
├── Dio (HTTP client)
├── SQLite (Bible data, offline)
└── flutter_secure_storage (JWT + API key)

Backend API (Node.js)
├── Express
├── MongoDB Atlas
├── Mongoose
└── JWT auth

AI (OpenAI API)
├── GPT-4.1-mini (free plan)
└── GPT-4.1 (premium)
```
