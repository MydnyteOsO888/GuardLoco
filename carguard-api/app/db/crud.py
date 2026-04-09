from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, desc
from sqlalchemy.orm import selectinload
from typing import Optional
from datetime import datetime, timezone

from . import models
from ..core.security import hash_password


# ── Users ─────────────────────────────────────────────────
async def get_user_by_id(db: AsyncSession, user_id: str) -> Optional[models.User]:
    result = await db.execute(select(models.User).where(models.User.id == user_id))
    return result.scalar_one_or_none()

async def get_user_by_email(db: AsyncSession, email: str) -> Optional[models.User]:
    result = await db.execute(select(models.User).where(models.User.email == email))
    return result.scalar_one_or_none()

async def create_user(db: AsyncSession, email: str, password: str, display_name: str = None) -> models.User:
    user = models.User(
        email=email,
        hashed_password=hash_password(password),
        display_name=display_name,
    )
    db.add(user)
    await db.flush()
    return user

async def update_fcm_token(db: AsyncSession, user_id: str, token: str):
    await db.execute(
        update(models.User).where(models.User.id == user_id).values(fcm_token=token)
    )


# ── Security Events ───────────────────────────────────────
async def create_event(
    db: AsyncSession,
    user_id: str,
    event_type: models.EventType,
    sensor_value: float = None,
) -> models.SecurityEvent:
    event = models.SecurityEvent(
        user_id=user_id,
        type=event_type,
        sensor_value=sensor_value,
    )
    db.add(event)
    await db.flush()
    return event

async def get_events(
    db: AsyncSession,
    user_id: str,
    skip: int = 0,
    limit: int = 20,
    event_type: models.EventType = None,
) -> list[models.SecurityEvent]:
    q = select(models.SecurityEvent).where(models.SecurityEvent.user_id == user_id)
    if event_type:
        q = q.where(models.SecurityEvent.type == event_type)
    q = q.order_by(desc(models.SecurityEvent.timestamp)).offset(skip).limit(limit)
    result = await db.execute(q)
    return result.scalars().all()

async def mark_event_read(db: AsyncSession, event_id: str, user_id: str):
    await db.execute(
        update(models.SecurityEvent)
        .where(models.SecurityEvent.id == event_id, models.SecurityEvent.user_id == user_id)
        .values(is_read=True)
    )

async def mark_notification_sent(db: AsyncSession, event_id: str):
    await db.execute(
        update(models.SecurityEvent)
        .where(models.SecurityEvent.id == event_id)
        .values(notification_sent=True)
    )


# ── Video Clips ───────────────────────────────────────────
async def create_clip(
    db: AsyncSession,
    user_id: str,
    event_type: models.EventType,
    event_id: str = None,
    duration_seconds: int = 0,
    file_size_bytes: int = 0,
    resolution: str = "1080p",
    local_path: str = None,
    s3_key: str = None,
) -> models.VideoClip:
    clip = models.VideoClip(
        user_id=user_id,
        event_id=event_id,
        event_type=event_type,
        duration_seconds=duration_seconds,
        file_size_bytes=file_size_bytes,
        resolution=resolution,
        local_path=local_path,
        s3_key=s3_key,
        is_cloud_synced=s3_key is not None,
    )
    db.add(clip)
    await db.flush()
    return clip

async def get_clips(
    db: AsyncSession,
    user_id: str,
    skip: int = 0,
    limit: int = 20,
    event_type: models.EventType = None,
) -> list[models.VideoClip]:
    q = select(models.VideoClip).where(models.VideoClip.user_id == user_id)
    if event_type:
        q = q.where(models.VideoClip.event_type == event_type)
    q = q.order_by(desc(models.VideoClip.timestamp)).offset(skip).limit(limit)
    result = await db.execute(q)
    return result.scalars().all()

async def get_clip_by_id(db: AsyncSession, clip_id: str, user_id: str) -> Optional[models.VideoClip]:
    result = await db.execute(
        select(models.VideoClip).where(
            models.VideoClip.id == clip_id,
            models.VideoClip.user_id == user_id,
        )
    )
    return result.scalar_one_or_none()

async def update_clip_s3(db: AsyncSession, clip_id: str, s3_key: str):
    await db.execute(
        update(models.VideoClip)
        .where(models.VideoClip.id == clip_id)
        .values(s3_key=s3_key, is_cloud_synced=True)
    )

async def delete_clip(db: AsyncSession, clip_id: str, user_id: str):
    await db.execute(
        delete(models.VideoClip).where(
            models.VideoClip.id == clip_id,
            models.VideoClip.user_id == user_id,
        )
    )


# ── Device Status ─────────────────────────────────────────
async def get_device_status(db: AsyncSession) -> Optional[models.DeviceStatus]:
    result = await db.execute(select(models.DeviceStatus).where(models.DeviceStatus.id == 1))
    return result.scalar_one_or_none()

async def upsert_device_status(db: AsyncSession, **kwargs) -> models.DeviceStatus:
    status = await get_device_status(db)
    if status:
        for k, v in kwargs.items():
            setattr(status, k, v)
        status.last_seen = datetime.now(timezone.utc)
    else:
        status = models.DeviceStatus(id=1, **kwargs)
        db.add(status)
    await db.flush()
    return status

async def set_armed(db: AsyncSession, armed: bool):
    await db.execute(
        update(models.DeviceStatus)
        .where(models.DeviceStatus.id == 1)
        .values(is_armed=armed)
    )


# ── Settings ──────────────────────────────────────────────
async def get_settings(db: AsyncSession) -> Optional[models.DeviceSettings]:
    result = await db.execute(select(models.DeviceSettings).where(models.DeviceSettings.id == 1))
    return result.scalar_one_or_none()

async def upsert_settings(db: AsyncSession, **kwargs) -> models.DeviceSettings:
    s = await get_settings(db)
    if s:
        for k, v in kwargs.items():
            if hasattr(s, k):
                setattr(s, k, v)
    else:
        s = models.DeviceSettings(id=1, **kwargs)
        db.add(s)
    await db.flush()
    return s


# ── Sensor Logs ───────────────────────────────────────────
async def log_sensor_reading(db: AsyncSession, **kwargs) -> models.SensorLog:
    log = models.SensorLog(**kwargs)
    db.add(log)
    await db.flush()
    return log
