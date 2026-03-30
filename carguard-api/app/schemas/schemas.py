from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
from datetime import datetime
from ..db.models import EventType


# ── Auth ─────────────────────────────────────────────────
class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    display_name: Optional[str] = None

    @field_validator("password")
    @classmethod
    def password_strength(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class RefreshRequest(BaseModel):
    refresh_token: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class UserResponse(BaseModel):
    id: str
    email: str
    display_name: Optional[str]
    class Config: from_attributes = True

class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserResponse


# ── FCM ───────────────────────────────────────────────────
class FCMTokenRequest(BaseModel):
    token: str


# ── Events ────────────────────────────────────────────────
class EventResponse(BaseModel):
    id: str
    type: EventType
    timestamp: datetime
    clip_id: Optional[str]
    sensor_value: Optional[float]
    is_read: bool
    class Config: from_attributes = True

class AlertPayload(BaseModel):
    """Sent by ESP32 when an event is detected."""
    event_type: EventType
    sensor_value: Optional[float] = None
    timestamp: Optional[datetime] = None


# ── Clips ─────────────────────────────────────────────────
class ClipResponse(BaseModel):
    id: str
    event_id: Optional[str]
    event_type: EventType
    timestamp: datetime
    duration_seconds: int
    file_size_bytes: int
    resolution: str
    is_cloud_synced: bool
    class Config: from_attributes = True

class ClipStreamUrlResponse(BaseModel):
    url: str
    expires_in: int


# ── Device ────────────────────────────────────────────────
class StorageInfo(BaseModel):
    total_bytes: int
    used_bytes: int
    video_bytes: int
    logs_bytes: int
    class Config: from_attributes = True

class SensorReadingResponse(BaseModel):
    vibration_g: float
    motion_detected: bool
    ultrasonic_meters: float
    temperature_c: float
    wifi_rssi: int
    timestamp: datetime
    class Config: from_attributes = True

class DeviceStatusResponse(BaseModel):
    is_online: bool
    is_armed: bool
    ip_address: str
    firmware_version: str
    uptime_seconds: int
    mcu_temp_c: float
    wifi_rssi: int
    storage: StorageInfo
    latest_reading: Optional[SensorReadingResponse] = None
    class Config: from_attributes = True

class ArmRequest(BaseModel):
    armed: bool

class DeviceHeartbeat(BaseModel):
    """ESP32 sends this periodically."""
    ip_address: str
    firmware_version: str
    uptime_seconds: int
    mcu_temp_c: float
    wifi_rssi: int
    is_armed: bool
    storage_total_bytes: int
    storage_used_bytes: int
    storage_video_bytes: int
    storage_logs_bytes: int
    vibration_g: float = 0.0
    motion_detected: bool = False
    ultrasonic_meters: float = 0.0
    temperature_c: float = 0.0


# ── WebRTC ────────────────────────────────────────────────
class SDPOffer(BaseModel):
    sdp: str
    type: str

class SDPAnswer(BaseModel):
    sdp: str
    type: str

class ICECandidate(BaseModel):
    candidate: str
    sdp_mid: str
    sdp_m_line_index: int


# ── Settings ──────────────────────────────────────────────
class SettingsResponse(BaseModel):
    resolution: str
    fps: int
    night_vision: bool
    webrtc_enabled: bool
    alert_motion: bool
    alert_impact: bool
    alert_sound: bool
    alert_proximity: bool
    local_storage: bool
    cloud_sync: bool
    auto_delete: bool
    clip_length: int
    encryption: bool
    class Config: from_attributes = True

class SettingsUpdateRequest(BaseModel):
    resolution: Optional[str] = None
    fps: Optional[int] = None
    night_vision: Optional[bool] = None
    webrtc_enabled: Optional[bool] = None
    alert_motion: Optional[bool] = None
    alert_impact: Optional[bool] = None
    alert_sound: Optional[bool] = None
    alert_proximity: Optional[bool] = None
    local_storage: Optional[bool] = None
    cloud_sync: Optional[bool] = None
    auto_delete: Optional[bool] = None
    clip_length: Optional[int] = None
