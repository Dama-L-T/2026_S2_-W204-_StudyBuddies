"""Match existing profiles, excluding the current student's saved choices."""
import re

FIELDS = ('name', 'courses', 'interests', 'preferences', 'profile_image')


def rows(query):
    result = []
    while True:
        page = query.range(len(result), len(result) + 499).execute().data or []
        result.extend(page)
        if len(page) < 500:
            return result


def profile_fields(profile, detailed=False):
    fields = (*FIELDS, 'personal_details') if detailed else FIELDS
    return {'user_id': profile['user_id'], **{key: profile.get(key) or '' for key in fields}}


def shared(own, other):
    def values(text):
        return [value.strip() for value in re.split(r'[,;\n]', text or '') if value.strip()]
    normalized = {value.casefold() for value in values(own)}
    found = {}
    for value in values(other):
        if value.casefold() in normalized:
            found.setdefault(value.casefold(), value)
    return list(found.values())


def recommendations(db, user_id, criterion):
    own = db.table('profiles').select('courses,interests').eq('user_id', user_id).execute().data
    if not own:
        raise LookupError('Complete your profile before finding study buddies.')
    choices = rows(db.table('matchmaking_interests').select('target_student_id').eq('student_id', user_id).order('target_student_id'))
    excluded = {user_id, *(choice['target_student_id'] for choice in choices)}
    profiles = rows(db.table('profiles').select('user_id,' + ','.join(FIELDS)).order('user_id'))
    results = []
    for profile in profiles:
        if profile['user_id'] in excluded:
            continue
        courses = shared(own[0].get('courses'), profile.get('courses')) if criterion != 'interests' else []
        interests = shared(own[0].get('interests'), profile.get('interests')) if criterion != 'courses' else []
        if courses or interests:
            results.append({'profile': profile_fields(profile), 'shared_courses': courses, 'shared_interests': interests})
    return sorted(results, key=lambda r: (-(len(r['shared_courses']) + len(r['shared_interests'])), r['profile']['user_id']))


def get_public_profile(db, user_id, target_id):
    if user_id == target_id:
        raise LookupError('Open your own profile from the Profile tab.')
    data = db.table('profiles').select('user_id,' + ','.join((*FIELDS, 'personal_details'))).eq('user_id', target_id).execute().data
    if not data:
        raise LookupError('Profile not found.')
    return profile_fields(data[0], detailed=True)


def save_choice(db, user_id, target_id, status):
    if status not in ('interested', 'uninterested'):
        raise ValueError('Invalid matchmaking status.')
    get_public_profile(db, user_id, target_id)
    db.table('matchmaking_interests').upsert({
        'student_id': user_id, 'target_student_id': target_id, 'status': status,
    }, on_conflict='student_id,target_student_id').execute()


def restore_dismissed(db, user_id):
    """Restore only this student's uninterested choices; retain interests."""
    db.table('matchmaking_interests').delete().eq(
        'student_id', user_id
    ).eq('status', 'uninterested').execute()


def saved_profiles(db, user_id, status):
    choices = rows(db.table('matchmaking_interests').select('target_student_id').eq(
        'student_id', user_id
    ).eq('status', status).order('target_student_id'))
    ids = [choice['target_student_id'] for choice in choices]
    profiles = []
    for start in range(0, len(ids), 100):
        batch = rows(db.table('profiles').select('user_id,' + ','.join(FIELDS)).in_(
            'user_id', ids[start:start + 100]
        ).order('user_id'))
        profiles.extend(profile_fields(profile) for profile in batch)
    return sorted(profiles, key=lambda p: (p['name'].casefold(), p['user_id']))


def restore_profile(db, user_id, target_id):
    """A stale Uninterested screen must never delete a newer Interested choice."""
    db.table('matchmaking_interests').delete().eq('student_id', user_id).eq(
        'target_student_id', target_id
    ).eq('status', 'uninterested').execute()


def remove_interest(db, user_id, target_id):
    """Remove only an Interested choice belonging to the authenticated student."""
    db.table('matchmaking_interests').delete().eq('student_id', user_id).eq(
        'target_student_id', target_id
    ).eq('status', 'interested').execute()


def matched_partners(db, user_id):
    """Return only accepted connections involving the authenticated student."""
    connections = rows(db.table('student_matching').select(
        'id,student_id,target_student_id'
    ).eq('status', 'accepted').or_(
        f'student_id.eq.{user_id},target_student_id.eq.{user_id}'
    ).order('id'))
    partner_ids = set()
    for connection in connections:
        sender, recipient = connection['student_id'], connection['target_student_id']
        if sender == user_id and recipient != user_id:
            partner_ids.add(recipient)
        elif recipient == user_id and sender != user_id:
            partner_ids.add(sender)
    profiles = []
    ids = sorted(partner_ids)
    for start in range(0, len(ids), 100):
        batch = rows(db.table('profiles').select(
            'user_id,name,courses,interests,profile_image,'
            'name_visible,courses_visible,interests_visible'
        ).in_('user_id', ids[start:start + 100]).order('user_id'))
        for row in batch:
            profile = {'user_id': row['user_id'],
                       'profile_image': row.get('profile_image') or ''}
            for field in ('name', 'courses', 'interests'):
                profile[field] = (row.get(field) or '') if row.get(field + '_visible') is True else ''
            profiles.append(profile)
    return sorted(profiles, key=lambda p: (p['name'].casefold(), p['user_id']))


class InvitationConflict(ValueError):
    pass


def send_invitation(db, user_id, target_id):
    """Create a pending request; never accept or overwrite an existing pair."""
    if user_id == target_id:
        raise ValueError('You cannot invite yourself.')
    get_public_profile(db, user_id, target_id)

    def existing_pair():
        result = db.table('student_matching').select(
            'id,student_id,target_student_id,status'
        ).in_('student_id', [user_id, target_id]).in_(
            'target_student_id', [user_id, target_id]
        ).limit(1).execute().data or []
        return result[0] if result else None

    def describe(connection):
        if connection['status'] == 'accepted':
            raise InvitationConflict('You are already matched with this student.')
        if connection['status'] == 'declined':
            raise InvitationConflict('This invitation was declined. It cannot be resent.')
        if connection['student_id'] != user_id:
            raise InvitationConflict('This student has already invited you. Respond to their invitation instead.')
        return {'id': connection['id'], 'status': 'pending',
                'message': 'Invitation sent. Waiting for their response.'}

    existing = existing_pair()
    if existing:
        return describe(existing)
    try:
        result = db.table('student_matching').insert({
            'student_id': user_id,
            'target_student_id': target_id,
            'status': 'pending',
        }).execute().data
    except Exception as error:
        # The unique pair index also protects simultaneous/reverse requests.
        if getattr(error, 'code', None) != '23505':
            raise
        existing = existing_pair()
        if existing is None:
            raise
        return describe(existing)
    if not result:
        raise RuntimeError('Invitation was not saved.')
    return describe(result[0])


def invitation_count(db, user_id):
    invitations = rows(db.table('student_matching').select('id').eq(
        'target_student_id', user_id
    ).eq('status', 'pending').order('id'))
    return {'count': len(invitations), 'ids': [invitation['id'] for invitation in invitations]}


def incoming_invitations(db, user_id):
    invitations = rows(db.table('student_matching').select(
        'id,student_id,created_at'
    ).eq('target_student_id', user_id).eq('status', 'pending').order('id'))
    ids = sorted({invitation['student_id'] for invitation in invitations})
    profiles = {}
    for start in range(0, len(ids), 100):
        for row in rows(db.table('profiles').select(
            'user_id,name,courses,interests,profile_image,'
            'name_visible,courses_visible,interests_visible'
        ).in_('user_id', ids[start:start + 100]).order('user_id')):
            profile = {'user_id': row['user_id'], 'profile_image': row.get('profile_image') or ''}
            for field in ('name', 'courses', 'interests'):
                profile[field] = (row.get(field) or '') if row.get(field + '_visible') is True else ''
            profiles[row['user_id']] = profile
    result = [{'id': invitation['id'], 'created_at': invitation['created_at'],
               'profile': profiles.get(invitation['student_id'], {'user_id': invitation['student_id']})}
              for invitation in invitations]
    return sorted(result, key=lambda invitation: (invitation['created_at'], invitation['id']), reverse=True)


def respond_to_invitation(db, user_id, invitation_id, status):
    if status not in ('accepted', 'declined'):
        raise ValueError('Choose accepted or declined.')
    existing = db.table('student_matching').select('id,status').eq(
        'id', invitation_id
    ).eq('target_student_id', user_id).limit(1).execute().data or []
    if not existing:
        raise LookupError('Invitation not found.')
    if existing[0]['status'] == status:
        return {'id': invitation_id, 'status': status}
    if existing[0]['status'] != 'pending':
        raise InvitationConflict('This invitation has already been answered. Refresh your invitations.')
    updated = db.table('student_matching').update({'status': status}).eq(
        'id', invitation_id
    ).eq('target_student_id', user_id).eq('status', 'pending').execute().data or []
    if not updated:
        raise InvitationConflict('This invitation changed. Refresh your invitations.')
    return {'id': invitation_id, 'status': status}
