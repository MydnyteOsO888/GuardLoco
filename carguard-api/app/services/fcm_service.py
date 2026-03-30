import json
from loguru import logger
from ..core.config import settings

# Lazy-init Firebase Admin so missing credentials don't crash startup
_firebase_initialized = False

def _init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return
    try:
        import firebase_admin
        from firebase_admin import credentials
        cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("Firebase Admin initialized")
    except Exception as e:
        logger.warning(f"Firebase init failed (FCM disabled): {e}")


async def send_alert_notification(
    fcm_token: str,
    event_type: str,
    event_id: str,
    clip_id: str = None,
    sensor_value: float = None,
) -> bool:
    """
    Send a push notification via FCM when ESP32 detects an event.
    Returns True on success, False on failure.
    """
    _init_firebase()
    if not _firebase_initialized:
        logger.warning("FCM not initialized — skipping push notification")
        return False

    try:
        from firebase_admin import messaging

        title, body = _build_notification_text(event_type, sensor_value)

        message = messaging.Message(
            token=fcm_token,
            notification=messaging.Notification(title=title, body=body),
            data={
                "event_type": event_type,
                "event_id":   event_id,
                "clip_id":    clip_id or "",
            },
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="carguard_alerts",
                    sound="default",
                    priority="max",
                    visibility="public",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound="default",
                        badge=1,
                        content_available=True,
                    )
                )
            ),
        )

        response = messaging.send(message)
        logger.info(f"FCM notification sent: {response} | type={event_type}")
        return True

    except Exception as e:
        logger.error(f"FCM send failed: {e}")
        return False


def _build_notification_text(event_type: str, sensor_value: float = None):
    """Build human-readable push notification text per event type."""
    templates = {
        "motion": (
            "⚠️ Motion Detected",
            "Movement detected near your vehicle",
        ),
        "impact": (
            "💥 Impact Alert",
            f"Vehicle impact detected ({sensor_value:.1f}g)" if sensor_value else "Vehicle impact detected",
        ),
        "sound": (
            "🔊 Sound Alert",
            "Loud noise detected near your vehicle",
        ),
        "proximity": (
            "📏 Proximity Alert",
            f"Object {sensor_value:.1f}m from vehicle" if sensor_value else "Object detected near vehicle",
        ),
        "scheduled": (
            "📅 Scheduled Recording",
            "Periodic check-in recording saved",
        ),
    }
    return templates.get(event_type, ("🚨 CarGuard Alert", "Security event detected"))
