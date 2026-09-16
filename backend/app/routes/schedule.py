import logging

from fastapi import APIRouter, HTTPException, Security
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.schemas.schedule import ScheduleItem, ScheduleItemCreate
from app.services.schedule_service import create_schedule_item, list_schedule_items

router = APIRouter(prefix="/schedule", tags=["schedule"])
auth_scheme = HTTPBearer(auto_error=False)
logger = logging.getLogger(__name__)


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
        logger.exception("Could not load upcoming study items")
        raise HTTPException(
            status_code=500,
            detail=f"Could not load upcoming study items: {error}",
        ) from error


@router.post("", response_model=ScheduleItem, status_code=201)
def post_schedule_item(
    payload: ScheduleItemCreate,
    credentials: HTTPAuthorizationCredentials | None = Security(auth_scheme),
) -> ScheduleItem:
    try:
        access_token = credentials.credentials if credentials else None
        return create_schedule_item(payload, access_token=access_token)
    except PermissionError as error:
        raise HTTPException(status_code=401, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    except Exception as error:
        logger.exception("Could not create schedule item")
        raise HTTPException(
            status_code=500,
            detail=f"Could not create schedule item: {error}",
        ) from error
