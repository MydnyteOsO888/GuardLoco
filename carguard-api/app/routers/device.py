from fastapi import APIRouter, Depends, HTTPException, Header
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
import httpx

from ..db.database import get_db
from ..db import crud
from ..core.dependencies import get_current_user, verify_jwt_only
from ..core.config import settings
from ..schemas.schemas import (
    DeviceStatusResponse, ArmRequest, FCMTokenRequest,
    StorageInfo, SensorReadingResponse, DeviceHeartbeat,
)
from ..services import esp32_service
from ..services.fcm_service import send_alert_notification

router = APIRouter(prefix="/device", tags=["Device"])


@router.get("/status", response_model=DeviceStatusResponse)
async def get_status(
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    """Get current ESP32 device status, sensors, and storage info."""
    status = await crud.get_device_status(db)
    if not status:
        raise HTTPException(status_code=404, detail="Device not found — send a heartbeat first")

    return DeviceStatusResponse(
        is_online=status.is_online,
        is_armed=status.is_armed,
        ip_address=status.ip_address,
        firmware_version=status.firmware_version,
        uptime_seconds=status.uptime_seconds,
        mcu_temp_c=status.mcu_temp_c,
        wifi_rssi=status.wifi_rssi,
        storage=StorageInfo(
            total_bytes=status.storage_total_bytes,
            used_bytes=status.storage_used_bytes,
            video_bytes=status.storage_video_bytes,
            logs_bytes=status.storage_logs_bytes,
        ),
    )


@router.post("/heartbeat")
async def heartbeat(
    body: DeviceHeartbeat,
    db: AsyncSession = Depends(get_db),
    x_api_key: Optional[str] = Header(None),
):
    """
    Called by ESP32 every ~5 seconds to report status and sensor readings.
    No JWT required — uses ESP32 API key instead.
    """
    if x_api_key != settings.ESP32_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid ESP32 API key")

    await crud.upsert_device_status(
        db,
        is_online=True,
        is_armed=body.is_armed,
        ip_address=body.ip_address,
        firmware_version=body.firmware_version,
        uptime_seconds=body.uptime_seconds,
        mcu_temp_c=body.mcu_temp_c,
        wifi_rssi=body.wifi_rssi,
        storage_total_bytes=body.storage_total_bytes,
        storage_used_bytes=body.storage_used_bytes,
        storage_video_bytes=body.storage_video_bytes,
        storage_logs_bytes=body.storage_logs_bytes,
    )

    # Log sensor reading
    await crud.log_sensor_reading(
        db,
        vibration_g=body.vibration_g,
        motion_detected=body.motion_detected,
        ultrasonic_meters=body.ultrasonic_meters,
        temperature_c=body.temperature_c,
        wifi_rssi=body.wifi_rssi,
    )

    return {"status": "ok"}


@router.post("/arm")
async def arm_device(
    body: ArmRequest,
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    """Arm or disarm the vehicle security system."""
    # Update DB
    await crud.set_armed(db, body.armed)
    # Forward command to ESP32 over local WiFi
    sent = await esp32_service.send_arm_command(body.armed)
    return {
        "armed": body.armed,
        "esp32_notified": sent,
    }


@router.post("/reboot")
async def reboot_device(_=Depends(get_current_user)):
    """Send reboot command to ESP32."""
    sent = await esp32_service.send_reboot_command()
    if not sent:
        raise HTTPException(status_code=503, detail="Could not reach ESP32")
    return {"status": "reboot command sent"}


@router.post("/fcm-token")
async def update_fcm_token(
    body: FCMTokenRequest,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Register or update the user's FCM device token for push notifications."""
    await crud.update_fcm_token(db, current_user.id, body.token)
    return {"status": "token updated"}


@router.get("/ping")
async def ping():
    """Health check endpoint."""
    return {"status": "ok", "service": "CarGuard API"}


@router.get("/snapshot")
async def snapshot(_: str = Depends(verify_jwt_only)):
    """Return latest JPEG — from MJPEG stream cache if available, else direct ESP32 fetch."""
    from ..main import frame_cache, esp32_client
    if frame_cache is not None:
        return Response(content=frame_cache, media_type="image/jpeg")
    # Cache not ready yet (MJPEG reader still connecting) — fall back to direct fetch
    try:
        resp = await esp32_client.get("/snapshot")
        if resp.status_code == 200:
            return Response(content=resp.content, media_type="image/jpeg")
        raise HTTPException(status_code=502, detail="ESP32 snapshot failed")
    except httpx.RequestError:
        raise HTTPException(status_code=503, detail="ESP32 unreachable")
