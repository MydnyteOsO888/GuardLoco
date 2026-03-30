from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from ..db.database import get_db
from ..db import crud, models
from ..core.dependencies import get_current_user
from ..core.config import settings
from ..schemas.schemas import EventResponse, AlertPayload
from ..services.fcm_service import send_alert_notification

router = APIRouter(prefix="/events", tags=["Events & Alerts"])


@router.post("/alert")
async def receive_alert(
    body: AlertPayload,
    db: AsyncSession = Depends(get_db),
    x_api_key: Optional[str] = Header(None),
):
    """
    Called by ESP32 when a security event is detected.
    1. Saves event to PostgreSQL
    2. Sends FCM push notification to user's phone
    3. Returns event ID so ESP32 can associate the video clip
    """
    if x_api_key != settings.ESP32_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid ESP32 API key")

    # Get the first active user (single-user system)
    # In a multi-user system, map ESP32 serial → user_id
    from sqlalchemy import select
    result = await db.execute(
        select(models.User).where(models.User.is_active == True).limit(1)
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="No active user found")

    # Save event to DB
    event = await crud.create_event(
        db,
        user_id=user.id,
        event_type=body.event_type,
        sensor_value=body.sensor_value,
    )

    # Send FCM push notification if user has a token
    notification_sent = False
    if user.fcm_token:
        notification_sent = await send_alert_notification(
            fcm_token=user.fcm_token,
            event_type=body.event_type.value,
            event_id=event.id,
            sensor_value=body.sensor_value,
        )
        if notification_sent:
            await crud.mark_notification_sent(db, event.id)

    return {
        "event_id": event.id,
        "notification_sent": notification_sent,
    }


@router.get("", response_model=list[EventResponse])
async def list_events(
    skip: int = 0,
    limit: int = 20,
    type: Optional[models.EventType] = None,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """List security events with optional type filter and pagination."""
    events = await crud.get_events(
        db,
        user_id=current_user.id,
        skip=skip,
        limit=limit,
        event_type=type,
    )
    return [EventResponse.model_validate(e) for e in events]


@router.patch("/{event_id}/read")
async def mark_read(
    event_id: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Mark a specific event as read."""
    await crud.mark_event_read(db, event_id, current_user.id)
    return {"status": "marked as read"}
