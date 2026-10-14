import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from fastapi import FastAPI
from fastapi.testclient import TestClient
from app.services import matchmaking_service as service
from app.routes import matchmaking
from app.services.auth_dependency import get_current_user_id

USER = '00000000-0000-0000-0000-000000000001'
TARGET = '00000000-0000-0000-0000-000000000002'


class Query:
    def __init__(self, records):
        self.records, self.filters = records, []
        self.start, self.end = 0, 999
    def select(self, _): return self
    def eq(self, key, value):
        self.filters.append(lambda row: row.get(key) == value)
        return self
    def order(self, _): return self
    def range(self, start, end):
        self.start, self.end = start, end
        return self
    def execute(self):
        return SimpleNamespace(data=[r for r in self.records if all(f(r) for f in self.filters)][self.start:self.end + 1])


class Database:
    def __init__(self):
        self.data = {
            'profiles': [
                {'user_id': 'me', 'courses': 'COMP611', 'interests': 'AI'},
                {'user_id': 'a', 'name': 'Alex', 'courses': 'comp611; COMP611', 'interests': 'AI', 'preferences': 'Evenings', 'personal_details': 'More details'},
                {'user_id': 'b', 'name': 'Sam', 'courses': 'ART101', 'interests': 'ai'},
                {'user_id': 'c', 'courses': 'ART101', 'interests': 'Painting'},
            ],
            'matchmaking_interests': [],
        }
    def table(self, name): return Query(self.data[name])


class MatchingTests(unittest.TestCase):
    def test_all_profiles_eligible_but_only_overlap_recommended(self):
        db = Database()
        result = service.recommendations(db, 'me', 'both')
        self.assertEqual([r['profile']['user_id'] for r in result], ['a', 'b'])
        self.assertEqual(result[0]['shared_courses'], ['comp611'])
        self.assertEqual(result[0]['profile']['preferences'], 'Evenings')
        self.assertNotIn('personal_details', result[0]['profile'])
        self.assertEqual([r['profile']['user_id'] for r in service.recommendations(db, 'me', 'courses')], ['a'])
        self.assertEqual(service.get_public_profile(db, 'me', 'a')['personal_details'], 'More details')

    def test_both_saved_statuses_excluded_only_for_own_account(self):
        db = Database()
        db.data['matchmaking_interests'] = [
            {'student_id': 'me', 'target_student_id': 'a', 'status': 'interested'},
            {'student_id': 'me', 'target_student_id': 'b', 'status': 'uninterested'},
        ]
        self.assertEqual(service.recommendations(db, 'me', 'both'), [])
        db.data['matchmaking_interests'][0]['student_id'] = 'someone-else'
        self.assertEqual([r['profile']['user_id'] for r in service.recommendations(db, 'me', 'both')], ['a'])

    def test_pagination(self):
        self.assertEqual(len(service.rows(Query([{'id': i} for i in range(1001)]))), 1001)

    def test_save_uses_agreed_table_columns_and_conflict_key(self):
        db = MagicMock()
        with patch.object(service, 'get_public_profile'):
            service.save_choice(db, USER, TARGET, 'uninterested')
        db.table.assert_called_once_with('matchmaking_interests')
        db.table.return_value.upsert.assert_called_once_with({
            'student_id': USER, 'target_student_id': TARGET, 'status': 'uninterested',
        }, on_conflict='student_id,target_student_id')


class RouteTests(unittest.TestCase):
    def setUp(self):
        self.app = FastAPI()
        self.app.include_router(matchmaking.router)
        self.db = MagicMock()
        self.app.dependency_overrides[matchmaking.database] = lambda: self.db
        self.client = TestClient(self.app)

    def test_requires_authentication(self):
        for method, path, body in [('GET', '/matchmaking', None), ('GET', f'/matchmaking/profiles/{TARGET}', None), ('PUT', f'/matchmaking/choices/{TARGET}', {'status': 'interested'})]:
            self.assertEqual(self.client.request(method, path, json=body).status_code, 401)
        self.db.table.assert_not_called()

    def test_verified_identity_and_status_validation(self):
        self.app.dependency_overrides[get_current_user_id] = lambda: USER
        with patch.object(service, 'save_choice') as save:
            self.assertEqual(self.client.put(f'/matchmaking/choices/{TARGET}', json={'status': 'interested', 'student_id': TARGET}).status_code, 204)
            save.assert_called_once_with(self.db, USER, TARGET, 'interested')
            self.assertEqual(self.client.put(f'/matchmaking/choices/{TARGET}', json={'status': 'skip'}).status_code, 422)
        self.assertEqual(self.client.get('/matchmaking?criterion=invalid').status_code, 422)

    def test_missing_profile_and_generic_server_error(self):
        self.app.dependency_overrides[get_current_user_id] = lambda: USER
        with patch.object(service, 'get_public_profile', side_effect=LookupError('Profile not found')):
            self.assertEqual(self.client.get(f'/matchmaking/profiles/{TARGET}').status_code, 404)
        with patch.object(service, 'recommendations', side_effect=RuntimeError('private db detail')):
            with self.assertLogs(matchmaking.logger, level='ERROR'):
                response = self.client.get('/matchmaking')
            self.assertEqual(response.status_code, 503)
            self.assertNotIn('private db detail', response.text)
