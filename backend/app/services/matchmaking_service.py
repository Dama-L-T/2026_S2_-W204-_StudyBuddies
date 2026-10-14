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
