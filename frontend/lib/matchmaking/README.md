# Matchmaking

Uses real profiles and the agreed `matchmaking_interests` table with columns
`student_id`, `target_student_id`, `status`, `created_at`, and `updated_at`.
`status` is interested or uninterested; the student pair must be unique.
No opt-in columns or other new tables are required. All profiles are eligible,
with recommendations filtered by shared courses, interests, or either.

Left swipe skips a profile only in the current swipe session and never calls a
write endpoint. Right swipe saves interested; Uninterested saves uninterested.
Both saved statuses exclude the profile from future recommendations. X exits
and clears session skips. Send request creates a pending invitation in student_matching. Tap a profile
to view the existing ProfilePage in read-only mode, including detailed fields.

GET /matchmaking?criterion=courses|interests|both
GET /matchmaking/profiles/{student_id}
PUT /matchmaking/choices/{student_id} with {"status":"interested|uninterested"}

The acting student is derived from the verified access token on the backend.
Swiping saves interest only; requests are sent explicitly using Send request or Send invite. Profile images currently require an
HTTP(S) URL in the existing profile_image field. General profile visibility
controls remain for the profile team's story.

The main Match screen has Interested and Uninterested buttons. Each opens a
server-backed list with photo, name, and profile viewing. Both lists have an X
button per student. A confirmation dialog offers Cancel/Remove and explains
that removal lets the student appear in recommendations again. No request is
sent until removal is confirmed. Interested also has a Send invite action backed by the same invitation endpoint. The Uninterested list has no invitation action.

GET /matchmaking/choices?status=interested|uninterested loads the current account's
saved profiles. DELETE /matchmaking/interests/{student_id} removes an Interested
choice; DELETE /matchmaking/dismissals/{student_id} removes an Uninterested choice.
Both endpoints are scoped to the authenticated owner, target, and current status.
Failures keep the entry visible for retry. Matching criteria still apply after
removal.


## Matched partners (story #77)

The Match screen's Matched partners button loads `GET /matchmaking/partners`.
The backend derives the student ID from the verified access token and returns
profiles only for `student_matching` rows with status `accepted` where that
student is either participant. Pending/declined requests and saved interest
choices are not matches. Missing/deleted profiles are skipped, duplicates are
removed, and hidden names/courses/interests are omitted. Empty state, loading,
retry and pull-to-refresh are supported.

Before deployment, run `backend/sql/student_matching.sql` in the Supabase SQL
editor. This creates a new table; do not run it over a different existing table
without reviewing its schema. It does not change matchmaking_interests.

Rows use student_id (sender), target_student_id (recipient), and status
(pending/accepted/declined). The UUIDs reference auth.users, not generated profile
IDs. RLS permits both participants to read, the sender to insert a pending
request, and only the recipient to accept/decline pending requests. Direct
client inserts omit status so the database default applies. Recipient updates
set status only. The pair is unique regardless of direction. The existing
service-role backend must continue deriving identity and checking authorization
explicitly in any future invitation write endpoints.

The accepted-partners list is read-only. Sending invitations is implemented;
accept/decline UI, chat creation, declined-request retries and connection removal
remain separate workflows. Interest alone never creates an accepted match. Until invitation
acceptance writes accepted rows, new accounts correctly see No matches yet.


## Send invitations

POST /matchmaking/invitations/{student_id} creates a pending row using the
verified sender ID. Both Send request on the recommendation card and Send invite
in Interested call this endpoint. Buttons disable during requests and change to
Request sent/Invite sent after success. Failures preserve the profile for retry.
Sending does not accept a match, create a chat, or change saved swipe choices.
The student_matching SQL must be applied first.

Repeated outgoing pending requests return success without another insert. An
incoming pending request, an existing accepted match, or a declined request
returns 409 without changing the row. The unique unordered-pair index handles
concurrent sends. Invitations are not email/push notifications. The recipient
inbox and accept/decline controls still need implementation.
