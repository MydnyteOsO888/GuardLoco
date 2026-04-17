from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from .security import verify_access_token
from ..db.database import get_db
from ..db import crud

bearer_scheme = HTTPBearer()


async def verify_jwt_only(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> str:
    """Validate JWT without a DB lookup — returns user_id. Use for high-frequency endpoints."""
    return verify_access_token(credentials.credentials)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
):
    """Extract and validate JWT, return the current User ORM object."""
    token = credentials.credentials
    user_id = verify_access_token(token)

    user = await crud.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled",
        )
    return user
