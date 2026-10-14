# Matchmaking

Uses real profiles and the agreed `matchmaking_interests` table with columns
`student_id`, `target_student_id`, `status`, `created_at`, and `updated_at`.
`status` is interested or uninterested; the student pair must be unique.
No opt-in columns or other new tables are required. All profiles are eligible,
with recommendations filtered by shared courses, interests, or either.

Left swipe skips a profile only in the current swipe session and never calls a
write endpoint. Right swipe saves interested; Uninterested saves uninterested.
Both saved statuses exclude the profile from future recommendations. X exits
and clears session skips. Send request is a disabled placeholder. Tap a profile
to view the existing ProfilePage in read-only mode, including detailed fields.

GET /matchmaking?criterion=courses|interests|both
GET /matchmaking/profiles/{student_id}
PUT /matchmaking/choices/{student_id} with {"status":"interested|uninterested"}

The acting student is derived from the verified access token on the backend.
The separate saved-list review screens and request workflow belong to later
stories. No request is sent by swiping. Profile images currently require an
HTTP(S) URL in the existing profile_image field. General profile visibility
controls remain for the profile team's story.
