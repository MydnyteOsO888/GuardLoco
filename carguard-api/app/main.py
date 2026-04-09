from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from loguru import logger
import time

from .core.config import settings
from .db.database import init_db
from .routers import auth, device, events, clips, sensors, webrtc, settings as settings_router


# ── Lifespan (startup / shutdown) ────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(f"Starting {settings.APP_NAME} [{settings.APP_ENV}]")
    # Create DB tables on startup (use Alembic migrations in production)
    await init_db()
    logger.info("Database tables ready")
    yield
    logger.info("Shutting down CarGuard API")


# ── App instance ──────────────────────────────────────────
app = FastAPI(
    title="CarGuard API",
    description="""
## CarGuard Vehicle Security System — Backend API

Handles:
- [JWT Authentication] (login, register, token refresh)
- [FCM Push Notifications] (motion, impact, sound, proximity alerts)
- [WebRTC Signaling] (SDP offer/answer + ICE candidates for live stream)
- [Device Management] (arm/disarm, heartbeat, reboot)
- [Sensor SSE Stream] (real-time MPU-6050 / PIR / HC-SR04 data)
- [Video Clip Storage] (AWS S3 upload, presigned URLs, AES-256 encryption)
- [Event Log] (PostgreSQL — all security events with timestamps)
    """,
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)


# ── CORS ──────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request timing middleware ─────────────────────────────
@app.middleware("http")
async def add_timing_header(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    duration_ms = (time.perf_counter() - start) * 1000
    response.headers["X-Response-Time"] = f"{duration_ms:.1f}ms"
    return response


# ── Global error handler ──────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled error on {request.url}: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error"},
    )


# ── Routers ───────────────────────────────────────────────
API_PREFIX = "/api/v1"

app.include_router(auth.router,             prefix=API_PREFIX)
app.include_router(device.router,           prefix=API_PREFIX)
app.include_router(events.router,           prefix=API_PREFIX)
app.include_router(clips.router,            prefix=API_PREFIX)
app.include_router(sensors.router,          prefix=API_PREFIX)
app.include_router(webrtc.router,           prefix=API_PREFIX)
app.include_router(settings_router.router,  prefix=API_PREFIX)


# ── Root ──────────────────────────────────────────────────
@app.get("/", tags=["Health"])
async def root():
    return {
        "service": "CarGuard API",
        "version": "1.0.0",
        "docs":    "/docs",
        "status":  "online",
    }

@app.get("/health", tags=["Health"])
async def health():
    return {"status": "healthy"}
