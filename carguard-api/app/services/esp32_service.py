import httpx
from loguru import logger
from ..core.config import settings


async def send_arm_command(armed: bool) -> bool:
    """Forward arm/disarm command to the ESP32 over local WiFi."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.post(
                f"{settings.esp32_base_url}/arm",
                json={"armed": armed},
                headers={"X-API-Key": settings.ESP32_API_KEY},
            )
            return resp.status_code == 200
    except httpx.RequestError as e:
        logger.warning(f"ESP32 arm command failed: {e}")
        return False


async def send_reboot_command() -> bool:
    """Send reboot command to ESP32."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.post(
                f"{settings.esp32_base_url}/reboot",
                headers={"X-API-Key": settings.ESP32_API_KEY},
            )
            return resp.status_code == 200
    except httpx.RequestError as e:
        logger.warning(f"ESP32 reboot command failed: {e}")
        return False


async def push_settings_to_device(settings_dict: dict) -> bool:
    """Push config changes (resolution, FPS, etc.) to ESP32."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.post(
                f"{settings.esp32_base_url}/settings",
                json=settings_dict,
                headers={"X-API-Key": settings.ESP32_API_KEY},
            )
            return resp.status_code == 200
    except httpx.RequestError as e:
        logger.warning(f"ESP32 settings push failed: {e}")
        return False


async def check_esp32_online() -> bool:
    """Ping ESP32 to see if it's reachable on the local network."""
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get(
                f"{settings.esp32_base_url}/ping",
                headers={"X-API-Key": settings.ESP32_API_KEY},
            )
            return resp.status_code == 200
    except httpx.RequestError:
        return False
