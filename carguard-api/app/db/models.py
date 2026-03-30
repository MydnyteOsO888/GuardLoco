import uuid
from datetime import datetime
from sqlalchemy import String, Boolean, DateTime, Float, Integer, Text, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
import enum
from .database import Base


class EventType(str, enum.Enum):
    motion    = "motion"
    impact    = "impact"
    sound     = "sound"
    proximity = "proximity"
    scheduled = "scheduled"


# ── User ─────────────────────────────────────────────────
class User(Base):
    __tablename__ = "users"

    id:           Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email:        Mapped[str] = mapped_column(String, unique=True, index=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String, nullable=False)
    display_name: Mapped[str | None] = mapped_column(String, nullable=True)
    fcm_token:    Mapped[str | None] = mapped_column(String, nullable=True)
    is_active:    Mapped[bool] = mapped_column(Boolean, default=True)
    created_at:   Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at:   Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    events: Mapped[list["SecurityEvent"]] = relationship("SecurityEvent", back_populates="user")
    clips:  Mapped[list["VideoClip"]]     = relationship("VideoClip",     back_populates="user")


# ── Security Event ────────────────────────────────────────
class SecurityEvent(Base):
    __tablename__ = "security_events"

    id:            Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id:       Mapped[str] = mapped_column(String, ForeignKey("users.id"), nullable=False)
    type:          Mapped[EventType] = mapped_column(SAEnum(EventType), nullable=False)
    timestamp:     Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    sensor_value:  Mapped[float | None] = mapped_column(Float, nullable=True)   # g-force, meters, dB
    location:      Mapped[str | None]   = mapped_column(String, nullable=True)  # GPS if available
    is_read:       Mapped[bool]         = mapped_column(Boolean, default=False)
    notification_sent: Mapped[bool]     = mapped_column(Boolean, default=False)
    clip_id:       Mapped[str | None]   = mapped_column(String, ForeignKey("video_clips.id"), nullable=True)

    user: Mapped["User"]            = relationship("User", back_populates="events")
    clip: Mapped["VideoClip | None"] = relationship("VideoClip", foreign_keys=[clip_id])


# ── Video Clip ────────────────────────────────────────────
class VideoClip(Base):
    __tablename__ = "video_clips"

    id:               Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id:          Mapped[str] = mapped_column(String, ForeignKey("users.id"), nullable=False)
    event_id:         Mapped[str | None] = mapped_column(String, nullable=True)
    event_type:       Mapped[EventType]  = mapped_column(SAEnum(EventType), nullable=False)
    timestamp:        Mapped[datetime]   = mapped_column(DateTime, default=datetime.utcnow, index=True)
    duration_seconds: Mapped[int]        = mapped_column(Integer, default=0)
    file_size_bytes:  Mapped[int]        = mapped_column(Integer, default=0)
    resolution:       Mapped[str]        = mapped_column(String, default="1080p")
    local_path:       Mapped[str | None] = mapped_column(String, nullable=True)   # SD card path on ESP32
    s3_key:           Mapped[str | None] = mapped_column(String, nullable=True)   # AWS S3 object key
    is_cloud_synced:  Mapped[bool]       = mapped_column(Boolean, default=False)
    created_at:       Mapped[datetime]   = mapped_column(DateTime, default=datetime.utcnow)

    user: Mapped["User"] = relationship("User", back_populates="clips")


# ── Device Status ─────────────────────────────────────────
class DeviceStatus(Base):
    __tablename__ = "device_status"

    id:               Mapped[int]   = mapped_column(Integer, primary_key=True, autoincrement=True)
    is_online:        Mapped[bool]  = mapped_column(Boolean, default=False)
    is_armed:         Mapped[bool]  = mapped_column(Boolean, default=True)
    ip_address:       Mapped[str]   = mapped_column(String, default="")
    firmware_version: Mapped[str]   = mapped_column(String, default="")
    uptime_seconds:   Mapped[int]   = mapped_column(Integer, default=0)
    mcu_temp_c:       Mapped[float] = mapped_column(Float, default=0.0)
    wifi_rssi:        Mapped[int]   = mapped_column(Integer, default=0)
    storage_total_bytes: Mapped[int] = mapped_column(Integer, default=0)
    storage_used_bytes:  Mapped[int] = mapped_column(Integer, default=0)
    storage_video_bytes: Mapped[int] = mapped_column(Integer, default=0)
    storage_logs_bytes:  Mapped[int] = mapped_column(Integer, default=0)
    last_seen:        Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at:       Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# ── Sensor Reading Log ────────────────────────────────────
class SensorLog(Base):
    __tablename__ = "sensor_logs"

    id:                  Mapped[int]   = mapped_column(Integer, primary_key=True, autoincrement=True)
    timestamp:           Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    vibration_g:         Mapped[float] = mapped_column(Float, default=0.0)
    motion_detected:     Mapped[bool]  = mapped_column(Boolean, default=False)
    ultrasonic_meters:   Mapped[float] = mapped_column(Float, default=0.0)
    temperature_c:       Mapped[float] = mapped_column(Float, default=0.0)
    wifi_rssi:           Mapped[int]   = mapped_column(Integer, default=0)


# ── Device Settings ───────────────────────────────────────
class DeviceSettings(Base):
    __tablename__ = "device_settings"

    id:                Mapped[int]  = mapped_column(Integer, primary_key=True, default=1)
    resolution:        Mapped[str]  = mapped_column(String,  default="1080p")
    fps:               Mapped[int]  = mapped_column(Integer, default=30)
    night_vision:      Mapped[bool] = mapped_column(Boolean, default=True)
    webrtc_enabled:    Mapped[bool] = mapped_column(Boolean, default=True)
    alert_motion:      Mapped[bool] = mapped_column(Boolean, default=True)
    alert_impact:      Mapped[bool] = mapped_column(Boolean, default=True)
    alert_sound:       Mapped[bool] = mapped_column(Boolean, default=False)
    alert_proximity:   Mapped[bool] = mapped_column(Boolean, default=True)
    local_storage:     Mapped[bool] = mapped_column(Boolean, default=True)
    cloud_sync:        Mapped[bool] = mapped_column(Boolean, default=True)
    auto_delete:       Mapped[bool] = mapped_column(Boolean, default=True)
    clip_length:       Mapped[int]  = mapped_column(Integer, default=30)
    encryption:        Mapped[bool] = mapped_column(Boolean, default=True)
    updated_at:        Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# ── WebRTC Session ────────────────────────────────────────
class WebRTCSession(Base):
    __tablename__ = "webrtc_sessions"

    id:            Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    sdp_offer:     Mapped[str | None] = mapped_column(Text, nullable=True)
    sdp_answer:    Mapped[str | None] = mapped_column(Text, nullable=True)
    ice_candidates: Mapped[str | None] = mapped_column(Text, nullable=True)  # JSON array
    created_at:    Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    expires_at:    Mapped[datetime] = mapped_column(DateTime)
