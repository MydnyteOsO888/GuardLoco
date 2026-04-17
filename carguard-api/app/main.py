import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute
from loguru import logger
import httpx
import time

from .core.config import settings
from .db.database import init_db
from .routers import auth, device, events, clips, sensors, webrtc, settings as settings_router

# Persistent HTTP client for ESP32 control endpoints
esp32_client: httpx.AsyncClient | None = None

# Latest JPEG frame read from the ESP32 MJPEG stream
frame_cache: bytes | None = None


async def _mjpeg_reader():
    """Background task: connects to ESP32 MJPEG stream and keeps frame_cache fresh."""
    global frame_cache
    while True:
        try:
            async with httpx.AsyncClient(
                timeout=httpx.Timeout(connect=5.0, read=None, write=5.0, pool=5.0)
            ) as stream_client:
                async with stream_client.stream("GET", settings.esp32_stream_url) as resp:
                    buffer = b""
                    async for chunk in resp.aiter_bytes(chunk_size=4096):
                        buffer += chunk
                        # Extract complete JPEG frames by SOI/EOI markers
                        while True:
                            start = buffer.find(b"\xff\xd8")
                            end   = buffer.find(b"\xff\xd9", start + 2) if start != -1 else -1
                            if start != -1 and end != -1:
                                frame_cache = buffer[start : end + 2]
                                buffer = buffer[end + 2:]
                            else:
                                break
                        # Prevent unbounded growth if no valid frames arrive
                        if len(buffer) > 200_000:
                            buffer = buffer[-50_000:]
        except Exception as e:
            logger.warning(
                f"MJPEG reader error ({type(e).__name__}: {e or 'no detail'}) "
                f"— target: {settings.esp32_stream_url} — retrying in 3s"
            )
            await asyncio.sleep(3)


# ── Lifespan (startup / shutdown) ────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    global esp32_client
    logger.info(f"Starting {settings.APP_NAME} [{settings.APP_ENV}]")
    await init_db()
    logger.info("Database tables ready")
    esp32_client = httpx.AsyncClient(
        base_url=settings.esp32_base_url,
        timeout=httpx.Timeout(connect=3.0, read=5.0, write=3.0, pool=3.0),
    )
    logger.info("ESP32 HTTP client ready")
    reader_task = asyncio.create_task(_mjpeg_reader())
    logger.info("MJPEG frame reader started")
    yield
    reader_task.cancel()
    await esp32_client.aclose()
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

# Serialize all Pydantic response models by alias (camelCase) for the Flutter client.
for _route in app.routes:
    if isinstance(_route, APIRoute) and _route.response_model is not None:
        _route.response_model_by_alias = True


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
