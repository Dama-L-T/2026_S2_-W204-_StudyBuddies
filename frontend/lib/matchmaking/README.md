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
chat creation, declined-request retries and connection removal remain separate workflows. Interest alone never creates an accepted match. Until invitation
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
concurrent sends. Invitations are not email/push notifications. Recipients can now respond from Incoming invitations.


## Incoming invitations and responses

GET /matchmaking/invitations lists pending requests addressed to the verified
student, with visibility-filtered sender names/courses/interests. The inbox
supports Accept/Decline, refresh and errors that retain the row for retry.
PATCH /matchmaking/invitations/{invitation_id} accepts a status of accepted or
declined. It scopes both reads and writes to the authenticated recipient and
updates only pending requests. Identical repeated responses are idempotent;
conflicting or concurrent responses return 409. A sender cannot accept their
own outgoing request. Accepted rows appear in both participants' Matched partners.

GET /matchmaking/invitations/count supplies an in-app badge on the Match tab
and Incoming invitations button. Counts refresh every 15 seconds while their
widgets are mounted and when returning from the inbox. The existing
LocalNotificationService also shows a banner for each newly detected invitation
after the initial successful poll. Existing pending requests seed the baseline
and appear in the badge without repeat alerts on login. Tapping a banner opens
the inbox, including a notification launch handled by main.dart. Schedule
reminder synchronization preserves invitation/chat alerts. Detection is app-side
polling, not background push delivery. No extra SQL is required beyond student_matching.sql.
Chat creation remains for the chat integration owner; acceptance currently only
updates student_matching and does not insert chat_conversations.


## Persistent invitation button states

Interested loads `GET /matchmaking/invitations/statuses` alongside saved profiles.
The authenticated endpoint returns outgoing_pending/incoming_pending/accepted/
declined states keyed by partner ID. Only pairs involving the verified student
are returned. Existing requests render disabled Pending invite, Invitation
received, Matched, or Invite declined labels. A fresh Send invite action appears
only when no connection exists and status loading succeeded. Pull to refresh or
reopen the page to update statuses. A successful send immediately becomes Pending
invite. Failed status loads disable sending until retry succeeds. The existing
backend unique-pair constraint and duplicate handling remain authoritative across
devices; there is no resend operation or extra SQL migration.
