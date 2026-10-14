import logging
from typing import Literal
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel
from app.services.auth_dependency import get_current_user_id
from app.services.supabase_service import get_supabase_client
from app.services import matchmaking_service as service

router = APIRouter(prefix='/matchmaking', tags=['Matchmaking'])
logger = logging.getLogger(__name__)


def database():
    return get_supabase_client(use_service_role=True)


def run(operation):
    try:
        return operation()
    except LookupError as error:
        raise HTTPException(404, str(error)) from error
    except Exception as error:
        logger.exception('Matchmaking database operation failed')
        raise HTTPException(503, 'Matchmaking is unavailable. Please try again later.') from error


class Choice(BaseModel):
    status: Literal['interested', 'uninterested']


@router.get('')
def find_students(criterion: Literal['courses', 'interests', 'both'] = 'both', user_id: str = Depends(get_current_user_id), db=Depends(database)):
    return run(lambda: service.recommendations(db, user_id, criterion))


@router.get('/profiles/{target_id}')
def view_profile(target_id: UUID, user_id: str = Depends(get_current_user_id), db=Depends(database)):
    return run(lambda: service.get_public_profile(db, user_id, str(target_id)))


@router.put('/choices/{target_id}', status_code=204)
def save_choice(target_id: UUID, payload: Choice, user_id: str = Depends(get_current_user_id), db=Depends(database)):
    def save():
        service.save_choice(db, user_id, str(target_id), payload.status)
        return Response(status_code=204)
    return run(save)
