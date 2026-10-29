# Random Forest Climate & Crop Productivity Monitoring and Decision Support System for Farmers

A FastAPI + PostgreSQL backend and a Flutter app that give rice farmers weather-based
planting advice, harvest/profit tracking, and a Random Forest yield forecast.

```
backend/       FastAPI API, Random Forest model, tests
mobile_app/    Flutter app (Android / iOS / web / desktop)
```

## Quick start

### 1. Backend

```bash
cd backend
python -m venv venv && source venv/bin/activate      # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env                                  # then fill in the values
uvicorn main:app --reload                             # http://127.0.0.1:8000/docs
```

`.env` needs `DATABASE_URL`, `OPENWEATHER_API_KEY` and a `JWT_SECRET` (32+ random characters;
the file explains how to generate one). Tables and the few new columns are created/added
automatically at startup. `schema.sql` is there if you prefer to manage the schema yourself.

### 2. Mobile app

```bash
cd mobile_app
flutter pub get
flutter run                                           # Android emulator -> http://10.0.2.2:8000 automatically
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000   # real phone on your Wi-Fi
```

### 3. Turn on yield forecasts

The forecast needs a trained model. Two options:

```bash
python train_model.py              # from your real harvest + climate records
python train_model.py --synthetic  # DEMO ONLY: invented data, clearly labelled in the API and app
```

Real training needs at least 10 harvest records whose farm has an area set and at least 3 saved
climate readings in the 120 days before harvest (readings are saved each time a farmer opens
Climate Monitoring). Until then, use the synthetic model for demos only. An admin account can also
retrain with `POST /predictions/train`. To make an admin, set `role = 'Admin'` for a user in the
`users` table.

## What the API does

| Area | Endpoints |
|---|---|
| Auth | `POST /register`, `POST /login` (returns a JWT), `GET /me` |
| Farms | `GET/POST /farms`, `GET/PATCH /farms/{id}` |
| Climate | `GET /climate/planting-advice?farm_id=`, `GET /weather/forecast`, `POST /climate/assess`, `GET /climate/history` |
| Productivity | `POST /productivity/evaluate`, `GET /productivity/records`, `GET /productivity/summary`, `DELETE /productivity/records/{id}` |
| Prediction | `GET /predictions/yield?farm_id=`, `GET /predictions/model`, `POST /predictions/train` (admin) |
| Health | `GET /health` |

All endpoints except `/register`, `/login` and `/health` need `Authorization: Bearer <token>`.
Interactive docs are at `/docs`.

## How the yield model works

- **Target:** harvested sacks per hectare. **Features:** mean temperature, mean daily rainfall and
  mean humidity of the saved readings in the 120 days before harvest.
- `RandomForestRegressor` (300 trees). Training reports cross-validated MAE and R² and out-of-bag R².
- Each forecast includes a 10th-90th percentile range taken from the individual trees. It is a
  spread of the model, not a guarantee.
- With only a few seasons of data the model will be weak. Treat the numbers as indicative, and
  read the reported error before trusting it.

## Tests

```bash
cd backend && pip install -r requirements-dev.txt && pytest      # 29 tests, SQLite, weather mocked
cd mobile_app && flutter test
```

## Changes from the original version

Breaking changes for existing clients are marked **(breaking)**.

**Security**
- JWT login. Every farm/climate/productivity endpoint now checks the farm belongs to the caller; before, any
  `farm_id` could be read or written by anyone **(breaking)**.
- Password hashing uses `bcrypt` directly (existing passlib `$2b$` hashes still work); passwords over
  72 bytes are rejected instead of crashing; unknown user, wrong password and wrong role all return the
  same message; repeated failed logins are temporarily locked out.
- Server errors no longer leak SQL/internals to the client; they are logged server-side.
- `JWT_SECRET` is mandatory; CORS origins are configurable.

**Backend**
- Split the 850-line `main.py` into routers/services; ORM models instead of hand-written SQL.
- Added the Random Forest model the project title promised (`scikit-learn` was installed but unused).
- One weather client with a 10-minute cache, shared by every endpoint (the app used to trigger two
  OpenWeather calls per refresh). Planting advice no longer writes a duplicate row on every refresh.
- The two rule sets (manual vs forecast) that used different thresholds are now one function.
- `requirements.txt` was missing `requests` and `passlib`/`bcrypt`; fixed (and `requests` replaced by `httpx`).
- New: farm list/update, area in hectares, climate history, productivity summary, delete record.

**Mobile app**
- `main.dart` (1,640 lines) split into screens, an API client and a session store.
- Fixed real bugs: the result and report screens showed "N/A" because the app read fields
  (`crop_name`, `performance_message`, `performance_status`) the API never returned; Farm ID
  was typed by hand; the API URL `127.0.0.1` cannot work on an Android emulator; the release Android
  manifest had no INTERNET permission; the only test was the stale Flutter counter template.
- Saved login between launches, expired-session handling, form validation, farm picker and
  "add farm", colour-coded advice, harvest summary, delete with confirmation, forecast screen.

## Known limits / next steps

- The planting-advice thresholds are preliminary; have them reviewed with PhilRice or the municipal
  agriculture office.
- The in-memory login lockout and weather cache are per process; use Redis or a proxy rate-limit
  if you run several workers.
- No admin screens in the app yet (admin features are API-only).
- Store the token in `flutter_secure_storage` for a production release (currently `shared_preferences`).
