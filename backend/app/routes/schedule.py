from fastapi import APIRouter, HTTPException, Security
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.schemas.schedule import ScheduleItem
from app.services.schedule_service import list_schedule_items

router = APIRouter(prefix="/schedule", tags=["schedule"])
auth_scheme = HTTPBearer(auto_error=False)


@router.get("", response_model=list[ScheduleItem])
def get_schedule(
    credentials: HTTPAuthorizationCredentials | None = Security(auth_scheme),
) -> list[ScheduleItem]:
    try:
        access_token = credentials.credentials if credentials else None
        return list_schedule_items(access_token=access_token)
    except PermissionError as error:
        raise HTTPException(status_code=401, detail=str(error)) from error
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail="Could not load upcoming study items",
        ) from error
