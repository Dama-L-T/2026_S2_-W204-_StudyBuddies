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
    except service.InvitationConflict as error:
        raise HTTPException(409, str(error)) from error
    except ValueError as error:
        raise HTTPException(422, str(error)) from error
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


class InvitationResponse(BaseModel):
    status: Literal['accepted', 'declined']


@router.get('/invitations')
def incoming_invitations(user_id: str = Depends(get_current_user_id), db=Depends(database)):
    return run(lambda: service.incoming_invitations(db, user_id))


@router.get('/invitations/statuses')
def invitation_statuses(user_id: str = Depends(get_current_user_id), db=Depends(database)):
    return run(lambda: service.invitation_statuses(db, user_id))


@router.get('/invitations/count')
def invitation_count(user_id: str = Depends(get_current_user_id), db=Depends(database)):
    return run(lambda: service.invitation_count(db, user_id))


@router.patch('/invitations/{invitation_id}')
def respond_to_invitation(invitation_id: UUID, payload: InvitationResponse, user_id: str = Depends(get_current_user_id), db=Depends(database)):
    return run(lambda: service.respond_to_invitation(db, user_id, str(invitation_id), payload.status))


@router.post('/invitations/{target_id}')
def send_invitation(target_id: UUID, user_id: str = Depends(get_current_user_id), db=Depends(database)):
    return run(lambda: service.send_invitation(db, user_id, str(target_id)))


@router.get('/partners')
def matched_partners(user_id: str = Depends(get_current_user_id), db=Depends(database)):
    return run(lambda: service.matched_partners(db, user_id))


@router.get('/profiles/{target_id}')
def view_profile(target_id: UUID, user_id: str = Depends(get_current_user_id), db=Depends(database)):
    return run(lambda: service.get_public_profile(db, user_id, str(target_id)))


@router.put('/choices/{target_id}', status_code=204)
def save_choice(target_id: UUID, payload: Choice, user_id: str = Depends(get_current_user_id), db=Depends(database)):
    def save():
        service.save_choice(db, user_id, str(target_id), payload.status)
        return Response(status_code=204)
    return run(save)


@router.delete('/dismissals', status_code=204)
def restore_dismissed(user_id: str = Depends(get_current_user_id), db=Depends(database)):
    def restore():
        service.restore_dismissed(db, user_id)
        return Response(status_code=204)
    return run(restore)


@router.get('/choices')
def saved_profiles(status: Literal['interested', 'uninterested'], user_id: str = Depends(get_current_user_id), db=Depends(database)):
    return run(lambda: service.saved_profiles(db, user_id, status))


@router.delete('/dismissals/{target_id}', status_code=204)
def restore_profile(target_id: UUID, user_id: str = Depends(get_current_user_id), db=Depends(database)):
    def restore():
        service.restore_profile(db, user_id, str(target_id))
        return Response(status_code=204)
    return run(restore)


@router.delete('/interests/{target_id}', status_code=204)
def remove_interest(target_id: UUID, user_id: str = Depends(get_current_user_id), db=Depends(database)):
    def remove():
        service.remove_interest(db, user_id, str(target_id))
        return Response(status_code=204)
    return run(remove)
