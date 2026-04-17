import uuid
from pathlib import Path
from loguru import logger

MEDIA_DIR = Path(__file__).parent.parent.parent / "media" / "clips"


def ensure_media_dir():
    MEDIA_DIR.mkdir(parents=True, exist_ok=True)


async def save_clip(image_bytes: bytes, clip_id: str = None) -> tuple[str, str]:
    """Save JPEG bytes to local media dir. Returns (clip_id, absolute_path)."""
    ensure_media_dir()
    if not clip_id:
        clip_id = str(uuid.uuid4())
    file_path = MEDIA_DIR / f"{clip_id}.jpg"
    file_path.write_bytes(image_bytes)
    logger.info(f"Saved clip locally: {file_path} ({len(image_bytes)} bytes)")
    return clip_id, str(file_path)


def get_clip_path(clip_id: str) -> Path:
    return MEDIA_DIR / f"{clip_id}.jpg"


async def delete_local_clip(clip_id: str) -> bool:
    path = get_clip_path(clip_id)
    if path.exists():
        path.unlink()
        return True
    return False
