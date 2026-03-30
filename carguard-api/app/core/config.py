from pydantic_settings import BaseSettings
from pydantic import field_validator
from typing import List
import os


class Settings(BaseSettings):
    # App
    APP_NAME: str = "CarGuard API"
    APP_ENV: str = "development"
    DEBUG: bool = True
    SECRET_KEY: str

    # Database
    DATABASE_URL: str
    DATABASE_URL_SYNC: str

    # JWT
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440   # 24h
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Firebase
    FIREBASE_SERVICE_ACCOUNT_PATH: str = "./firebase-service-account.json"

    # AWS S3
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_REGION: str = "us-east-1"
    AWS_S3_BUCKET: str = "carguard-video-storage"
    AWS_S3_PRESIGNED_URL_EXPIRY: int = 3600

    # ESP32
    ESP32_IP: str = "192.168.1.42"
    ESP32_PORT: int = 80
    ESP32_STREAM_PORT: int = 81
    ESP32_API_KEY: str = ""

    # CORS
    ALLOWED_ORIGINS: str = "http://localhost:3000"

    # Storage
    MAX_CLIP_DURATION_SECONDS: int = 60
    AUTO_DELETE_CLIPS_AFTER_DAYS: int = 7
    MAX_LOCAL_STORAGE_GB: int = 20

    @property
    def allowed_origins_list(self) -> List[str]:
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",")]

    @property
    def esp32_base_url(self) -> str:
        return f"http://{self.ESP32_IP}:{self.ESP32_PORT}"

    @property
    def esp32_stream_url(self) -> str:
        return f"http://{self.ESP32_IP}:{self.ESP32_STREAM_PORT}/stream"

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
