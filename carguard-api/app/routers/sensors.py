import asyncio
import json
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sse_starlette.sse import EventSourceResponse

from ..db.database import get_db
from ..db import crud
from ..core.dependencies import get_current_user
from ..core.config import settings

router = APIRouter(prefix="/sensors", tags=["Sensors"])

# In-memory store for the latest reading pushed by ESP32
_latest_reading: dict = {}


def update_latest_reading(data: dict):
    """Called by the heartbeat endpoint to update the in-memory sensor cache."""
    global _latest_reading
    _latest_reading = {**data, "timestamp": datetime.now(timezone.utc).isoformat()}


@router.get("/latest")
async def get_latest(
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    """Return the most recent sensor reading."""
    if _latest_reading:
        return _latest_reading
    # Fall back to DB if cache is empty
    from ..db.models import SensorLog
    from sqlalchemy import select, desc
    result = await db.execute(
        select(SensorLog).order_by(desc(SensorLog.timestamp)).limit(1)
    )
    log = result.scalar_one_or_none()
    if not log:
        return {"error": "No sensor data yet"}
    return {
        "vibration_g":       log.vibration_g,
        "motion_detected":   log.motion_detected,
        "ultrasonic_meters": log.ultrasonic_meters,
        "temperature_c":     log.temperature_c,
        "wifi_rssi":         log.wifi_rssi,
        "timestamp":         log.timestamp.isoformat(),
    }


@router.get("/stream")
async def sensor_stream(
    request: Request,
    _=Depends(get_current_user),
):
    """
    Server-Sent Events (SSE) stream of real-time sensor readings.
    Flutter app subscribes to this for live sensor updates on the Live screen.
    Sends a new event every second with latest ESP32 data.
    """
    async def event_generator():
        while True:
            # Check if client disconnected
            if await request.is_disconnected():
                break

            reading = _latest_reading or {
                "vibration_g":       0.0,
                "motion_detected":   False,
                "ultrasonic_meters": 0.0,
                "temperature_c":     0.0,
                "wifi_rssi":         0,
                "timestamp":         datetime.now(timezone.utc).isoformat(),
            }

            yield {
                "event": "sensor_reading",
                "data":  json.dumps(reading),
            }

            await asyncio.sleep(1)   # push every 1 second

    return EventSourceResponse(event_generator())
