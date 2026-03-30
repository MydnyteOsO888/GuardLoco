# CarGuard — FastAPI Backend

Real-time vehicle security API built with FastAPI, PostgreSQL, Firebase FCM, and AWS S3.

---

## Stack

| Component | Technology |
|---|---|
| API Framework | FastAPI (Python 3.11) |
| Database | PostgreSQL 16 + SQLAlchemy 2.0 async |
| Auth | JWT (python-jose) + bcrypt passwords |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Cloud Video Storage | AWS S3 with AES-256 encryption |
| Live Stream Signaling | WebRTC SDP/ICE via HTTP endpoints |
| Sensor Stream | Server-Sent Events (SSE) |
| Migrations | Alembic |
| Containerization | Docker + docker-compose |

---

## Project Structure

```
carguard-api/
├── app/
│   ├── main.py                  # FastAPI app, CORS, middleware, router registration
│   ├── core/
│   │   ├── config.py            # Settings from .env (pydantic-settings)
│   │   ├── security.py          # JWT creation/verification, bcrypt hashing
│   │   └── dependencies.py      # get_current_user FastAPI dependency
│   ├── db/
│   │   ├── database.py          # Async SQLAlchemy engine, session, Base
│   │   ├── models.py            # All ORM models (User, SecurityEvent, VideoClip, etc.)
│   │   └── crud.py              # All database operations
│   ├── schemas/
│   │   └── schemas.py           # Pydantic request/response models
│   ├── routers/
│   │   ├── auth.py              # POST /auth/login, /register, /refresh
│   │   ├── device.py            # GET /device/status, POST /device/arm, /heartbeat
│   │   ├── alerts.py            # POST /events/alert (from ESP32), GET /events
│   │   ├── clips.py             # GET/DELETE /clips, POST /clips/upload
│   │   ├── sensors.py           # GET /sensors/latest, GET /sensors/stream (SSE)
│   │   ├── webrtc.py            # POST /webrtc/offer, /ice-candidate, GET /ice-candidates
│   │   └── settings.py          # GET/PATCH /settings
│   └── services/
│       ├── fcm_service.py       # Firebase Admin SDK — send push notifications
│       ├── s3_service.py        # AWS S3 upload, presigned URLs, delete
│       └── esp32_service.py     # HTTP client for talking to ESP32 over WiFi
├── alembic/                     # Database migrations
├── tests/                       # Pytest tests
├── docker-compose.yml           # PostgreSQL + API containers
├── Dockerfile
├── requirements.txt
└── .env.example
```

---

## Quick Start

### Option A — Run Locally (No Docker)

**1. Install PostgreSQL**
```bash
brew install postgresql@16
brew services start postgresql@16
createdb carguard_db
createuser carguard --pwprompt    # set password to: password
```

**2. Create virtual environment**
```bash
cd carguard-api
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**3. Configure environment**
```bash
cp .env.example .env
# Edit .env and fill in your values
```

**4. Run database migrations**
```bash
alembic upgrade head
```

**5. Start the server**
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

---

### Option B — Run with Docker (Recommended)

```bash
cp .env.example .env
# Edit .env with your values

docker-compose up --build
```

Both PostgreSQL and the API start automatically.

---

## API Endpoints

All endpoints are prefixed with `/api/v1`.
Interactive docs available at: **http://localhost:8000/docs**

### Authentication
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| POST | `/auth/register` | Create account | None |
| POST | `/auth/login` | Sign in → JWT tokens | None |
| POST | `/auth/refresh` | Refresh access token | Refresh token |
| GET | `/auth/me` | Get current user | JWT |

### Device
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/device/status` | Full device health + storage | JWT |
| POST | `/device/heartbeat` | ESP32 reports status | API Key |
| POST | `/device/arm` | Arm or disarm system | JWT |
| POST | `/device/reboot` | Restart ESP32 | JWT |
| POST | `/device/fcm-token` | Register push token | JWT |

### Events & Alerts
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| POST | `/events/alert` | ESP32 reports event → FCM push | API Key |
| GET | `/events` | List events (filter by type) | JWT |
| PATCH | `/events/{id}/read` | Mark event as read | JWT |

### Video Clips
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/clips` | List clips (filter by type) | JWT |
| GET | `/clips/{id}/stream-url` | Get signed S3 URL | JWT |
| POST | `/clips/upload` | Upload clip from ESP32 | API Key |
| DELETE | `/clips/{id}` | Delete clip from S3 + DB | JWT |

### Sensors
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/sensors/latest` | Latest sensor snapshot | JWT |
| GET | `/sensors/stream` | SSE real-time sensor feed | JWT |

### WebRTC Signaling
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| POST | `/webrtc/offer` | Flutter sends SDP offer | JWT |
| POST | `/webrtc/answer` | ESP32 sends SDP answer | None |
| POST | `/webrtc/ice-candidate` | Add ICE candidate | JWT |
| GET | `/webrtc/ice-candidates` | Get ICE candidates | JWT |
| DELETE | `/webrtc/session` | End session | JWT |

### Settings
| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/settings` | Get device config | JWT |
| PATCH | `/settings` | Update config → push to ESP32 | JWT |

---

## Firebase Setup (FCM)

1. Go to **Firebase Console** → Project Settings → Service Accounts
2. Click **Generate new private key** → download JSON file
3. Save it as `firebase-service-account.json` in the project root
4. Set `FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json` in `.env`

---

## AWS S3 Setup

1. Create an S3 bucket named `carguard-video-storage`
2. Enable **Server-Side Encryption (AES-256)** on the bucket
3. Create an IAM user with `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject` permissions
4. Add the access key/secret to `.env`

---

## ESP32 Integration

The ESP32 communicates with the backend using its **API key** (no JWT).

Set `ESP32_API_KEY` in `.env` to match what's flashed on the ESP32.

The ESP32 calls:
- `POST /api/v1/device/heartbeat` — every 5 seconds
- `POST /api/v1/events/alert` — on motion/impact/sound/proximity
- `POST /api/v1/clips/upload` — after recording a clip
- `POST /api/v1/webrtc/answer` — during stream setup

---

## Running Tests

```bash
source venv/bin/activate
pytest tests/ -v
```

---

## Next Steps

- ESP32 Arduino firmware
- WebRTC STUN/TURN server configuration
- PostgreSQL production setup (connection pooling with PgBouncer)
- Deploy to AWS EC2 / Google Cloud Run
