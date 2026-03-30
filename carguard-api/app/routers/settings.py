from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ..db.database import get_db
from ..db import crud
from ..core.dependencies import get_current_user
from ..schemas.schemas import SettingsResponse, SettingsUpdateRequest
from ..services.esp32_service import push_settings_to_device

router = APIRouter(prefix="/settings", tags=["Settings"])


@router.get("", response_model=SettingsResponse)
async def get_settings(
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    """Return current device settings."""
    s = await crud.get_settings(db)
    if not s:
        # Return defaults if nothing saved yet
        s = await crud.upsert_settings(db)
    return SettingsResponse.model_validate(s)


@router.patch("", response_model=SettingsResponse)
async def update_settings(
    body: SettingsUpdateRequest,
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    """
    Update one or more device settings.
    Changes are saved to PostgreSQL and also pushed to the ESP32 over WiFi.
    """
    # Only send fields that were actually provided
    updates = body.model_dump(exclude_unset=True)

    s = await crud.upsert_settings(db, **updates)

    # Push relevant settings to ESP32 (camera, resolution, night vision, etc.)
    esp32_keys = {"resolution", "fps", "night_vision", "clip_length"}
    esp32_updates = {k: v for k, v in updates.items() if k in esp32_keys}
    if esp32_updates:
        await push_settings_to_device(esp32_updates)

    return SettingsResponse.model_validate(s)
