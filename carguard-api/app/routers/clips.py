from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Header
from fastapi.responses import FileResponse, Response
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
import tempfile, os, shutil
from pathlib import Path

from ..db.database import get_db
from ..db import crud
from ..db.models import EventType
from ..core.dependencies import get_current_user, verify_jwt_only
from ..core.config import settings
from ..schemas.schemas import ClipResponse, ClipStreamUrlResponse
from ..services.s3_service import generate_presigned_url, upload_clip, delete_clip as s3_delete, build_s3_key
from ..services.local_storage_service import get_clip_path, delete_local_clip

router = APIRouter(prefix="/clips", tags=["Video Clips"])


@router.get("", response_model=list[ClipResponse])
async def list_clips(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    type: Optional[EventType] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Return paginated video clips, optionally filtered by event type."""
    clips = await crud.get_clips(db, current_user.id, skip=skip, limit=limit, event_type=type)
    return [ClipResponse.model_validate(c) for c in clips]


@router.get("/{clip_id}/stream-url", response_model=ClipStreamUrlResponse)
async def get_stream_url(
    clip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Return a signed AWS S3 URL for streaming a clip in the Flutter video player.
    URL expires after AWS_S3_PRESIGNED_URL_EXPIRY seconds (default 1 hour).
    """
    clip = await crud.get_clip_by_id(db, clip_id, current_user.id)
    if not clip:
        raise HTTPException(status_code=404, detail="Clip not found")

    if clip.s3_key:
        url = await generate_presigned_url(clip.s3_key)
    elif clip.local_path:
        url = f"/api/v1/clips/{clip.id}/serve"
    else:
        raise HTTPException(status_code=404, detail="Clip file not found")

    return ClipStreamUrlResponse(
        url=url,
        expires_in=settings.AWS_S3_PRESIGNED_URL_EXPIRY,
    )


@router.post("/upload")
async def upload_clip_from_device(
    clip_id: str,
    event_type: EventType,
    duration_seconds: int = 0,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    x_api_key: Optional[str] = Header(None),
):
    """
    Called by ESP32 (or backend background task) to upload a recorded clip.
    Saves to S3 with AES-256 encryption, creates DB record.
    """
    if x_api_key != settings.ESP32_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid ESP32 API key")

    # Find owner user
    from ..db.models import User
    from sqlalchemy import select
    result = await db.execute(select(User).where(User.is_active == True).limit(1))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="No active user")

    # Save uploaded file temporarily
    with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as tmp:
        shutil.copyfileobj(file.file, tmp)
        tmp_path = tmp.name

    try:
        file_size = os.path.getsize(tmp_path)
        s3_key = build_s3_key(user.id, clip_id)

        # Upload to S3 (AES-256 server-side encryption applied in s3_service)
        uploaded = await upload_clip(tmp_path, s3_key)

        # Save clip record to DB
        clip = await crud.create_clip(
            db,
            user_id=user.id,
            event_type=event_type,
            event_id=clip_id,
            duration_seconds=duration_seconds,
            file_size_bytes=file_size,
            s3_key=s3_key if uploaded else None,
        )

        return {"clip_id": clip.id, "uploaded_to_s3": uploaded}

    finally:
        os.unlink(tmp_path)


@router.get("/{clip_id}/serve")
async def serve_clip(
    clip_id: str,
    db: AsyncSession = Depends(get_db),
    user_id: str = Depends(verify_jwt_only),
):
    """Serve a locally stored clip JPEG directly."""
    clip = await crud.get_clip_by_id(db, clip_id, user_id)
    if not clip:
        raise HTTPException(status_code=404, detail="Clip not found")
    if not clip.local_path:
        raise HTTPException(status_code=404, detail="No local file for this clip")
    path = Path(clip.local_path)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Clip file not found")
    return FileResponse(str(path), media_type="image/jpeg")


@router.delete("/{clip_id}")
async def delete_clip(
    clip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Delete a clip from DB, S3, and local storage."""
    clip = await crud.get_clip_by_id(db, clip_id, current_user.id)
    if not clip:
        raise HTTPException(status_code=404, detail="Clip not found")

    if clip.s3_key:
        await s3_delete(clip.s3_key)
    if clip.local_path:
        await delete_local_clip(clip_id)

    await crud.delete_clip(db, clip_id, current_user.id)
    return {"status": "deleted"}
