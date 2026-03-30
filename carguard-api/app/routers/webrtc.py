import json
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete

from ..db.database import get_db
from ..db import models
from ..core.dependencies import get_current_user
from ..schemas.schemas import SDPOffer, SDPAnswer, ICECandidate

router = APIRouter(prefix="/webrtc", tags=["WebRTC Signaling"])

# Active session ID shared between ESP32 and Flutter app
_active_session_id: str | None = None


@router.post("/offer", response_model=SDPAnswer)
async def receive_offer(
    body: SDPOffer,
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    """
    Flutter app sends its SDP offer here.
    Backend stores it and waits for the ESP32 to pick it up and reply.

    WebRTC flow:
      Flutter  --offer-->  FastAPI  --offer-->  ESP32
      Flutter  <-answer--  FastAPI  <-answer--  ESP32
    """
    global _active_session_id

    # Create a new signaling session
    session = models.WebRTCSession(
        sdp_offer=json.dumps({"sdp": body.sdp, "type": body.type}),
        ice_candidates=json.dumps([]),
        expires_at=datetime.utcnow() + timedelta(minutes=5),
    )
    db.add(session)
    await db.flush()
    _active_session_id = session.id

    # Poll for the ESP32's SDP answer (up to 10 seconds)
    import asyncio
    for _ in range(20):
        await asyncio.sleep(0.5)
        await db.refresh(session)
        if session.sdp_answer:
            answer = json.loads(session.sdp_answer)
            return SDPAnswer(sdp=answer["sdp"], type=answer["type"])

    raise HTTPException(
        status_code=504,
        detail="ESP32 did not respond in time. Check device is online.",
    )


@router.post("/answer")
async def receive_answer(body: SDPAnswer, db: AsyncSession = Depends(get_db)):
    """
    ESP32 posts its SDP answer here after receiving the offer.
    No JWT — ESP32 uses the active session ID.
    """
    if not _active_session_id:
        raise HTTPException(status_code=404, detail="No active WebRTC session")

    result = await db.execute(
        select(models.WebRTCSession).where(models.WebRTCSession.id == _active_session_id)
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    session.sdp_answer = json.dumps({"sdp": body.sdp, "type": body.type})
    return {"status": "answer received"}


@router.post("/ice-candidate")
async def add_ice_candidate(
    body: ICECandidate,
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    """Flutter app adds its ICE candidates to the signaling session."""
    if not _active_session_id:
        raise HTTPException(status_code=404, detail="No active WebRTC session")

    result = await db.execute(
        select(models.WebRTCSession).where(models.WebRTCSession.id == _active_session_id)
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    candidates = json.loads(session.ice_candidates or "[]")
    candidates.append({
        "candidate":       body.candidate,
        "sdpMid":          body.sdp_mid,
        "sdpMLineIndex":   body.sdp_m_line_index,
    })
    session.ice_candidates = json.dumps(candidates)
    return {"status": "candidate added"}


@router.get("/ice-candidates")
async def get_ice_candidates(
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    """Flutter polls this to get ICE candidates sent by the ESP32."""
    if not _active_session_id:
        return []

    result = await db.execute(
        select(models.WebRTCSession).where(models.WebRTCSession.id == _active_session_id)
    )
    session = result.scalar_one_or_none()
    if not session:
        return []

    return json.loads(session.ice_candidates or "[]")


@router.delete("/session")
async def close_session(
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    """Close the active WebRTC signaling session."""
    global _active_session_id
    if _active_session_id:
        await db.execute(
            delete(models.WebRTCSession).where(
                models.WebRTCSession.id == _active_session_id
            )
        )
    _active_session_id = None
    return {"status": "session closed"}
