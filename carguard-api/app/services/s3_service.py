import boto3
from botocore.exceptions import ClientError
from loguru import logger
from ..core.config import settings


def _get_s3_client():
    return boto3.client(
        "s3",
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        region_name=settings.AWS_REGION,
    )


async def generate_presigned_url(s3_key: str) -> str:
    """
    Generate a time-limited presigned URL for streaming a clip from S3.
    The Flutter app uses this URL directly with the video player.
    """
    try:
        s3 = _get_s3_client()
        url = s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": settings.AWS_S3_BUCKET, "Key": s3_key},
            ExpiresIn=settings.AWS_S3_PRESIGNED_URL_EXPIRY,
        )
        return url
    except ClientError as e:
        logger.error(f"S3 presigned URL failed: {e}")
        raise


async def upload_clip(local_path: str, s3_key: str, content_type: str = "video/mp4") -> bool:
    """
    Upload a video clip file to S3 with AES-256 server-side encryption.
    Per research doc: AES-256 encryption for data at rest.
    """
    try:
        s3 = _get_s3_client()
        s3.upload_file(
            local_path,
            settings.AWS_S3_BUCKET,
            s3_key,
            ExtraArgs={
                "ContentType": content_type,
                "ServerSideEncryption": "AES256",   # AES-256 at rest
            },
        )
        logger.info(f"Uploaded clip to S3: {s3_key}")
        return True
    except ClientError as e:
        logger.error(f"S3 upload failed: {e}")
        return False


async def delete_clip(s3_key: str) -> bool:
    """Delete a clip from S3 (called when user deletes a clip)."""
    try:
        s3 = _get_s3_client()
        s3.delete_object(Bucket=settings.AWS_S3_BUCKET, Key=s3_key)
        logger.info(f"Deleted clip from S3: {s3_key}")
        return True
    except ClientError as e:
        logger.error(f"S3 delete failed: {e}")
        return False


def build_s3_key(user_id: str, clip_id: str) -> str:
    """Consistent S3 key format: clips/{user_id}/{clip_id}.mp4"""
    return f"clips/{user_id}/{clip_id}.mp4"
