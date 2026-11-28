# Independent coaching API (MVP)

Coaching is independent of courses and organizations. MVP appointments are
**free and one-on-one** (D19). Existing course and class records are preserved;
classroom admission continues through the existing `class:` namespace.

Each booking has a private text conversation for its learner and coach, using the
same UI as hiring chat. See [applications and shared chat](applications-and-chat.md).

All endpoints below require a Bearer token:

| Method/path | Behavior |
| --- | --- |
| GET `/api/me/live-coaching` | Approved coach directory, available slots, caller's bookings, own profile/slots and `live_configured` |
| PUT `/api/coaching/profile` | Create/update the caller's profile: display_name, headline, bio, expertise[], session_minutes |
| POST `/api/coaching/slots` | Own availability at ISO8601 `starts_at` with offset; server derives the end |
| DELETE `/api/coaching/slots/:id` | Disable own unbooked slot |
| POST `/api/coaching/bookings` | Book `slot_id`; learner, price, status and timestamps are server-owned |
| PATCH `/api/coaching/bookings/:id` | `action: cancel` by either participant, or `complete` by the coach after the appointment ends |
| GET `/api/coaching/admin/profiles` | Platform superuser review queue |
| PATCH `/api/coaching/admin/profiles/:id` | Superuser sets pending/approved/suspended |

New profiles start pending. Only approved profiles are public; teacher status
never creates or publishes a coach. Users can be both learners and coaches.
Owners cannot submit approval or a different user_id through profile writes.
Coaches choose a duration of 15–120 minutes (default 30). Changing duration does
not modify already-created slots or bookings. This MVP has one service per
profile and concrete UTC slots, without recurring availability or paid checkout.

The directory returns published profile fields and unbooked future slots. It
exposes no user email or another person's booking details. Booking lists contain
only appointments where the caller is the learner or coach. There are no fake
ratings, course-derived coach profiles, or automatically seeded coach records.

Availability edits and reservations serialize on the coach's database row.
Reservations also lock the learner's user row, preventing overlapping confirmed
appointments across different coaches. A partial unique index permits only one
confirmed booking per slot. Conflicts return 409; unauthorized items return
404/403; malformed input returns 400/422. Self-booking is rejected. Cancelled
future slots become available again. A booked slot cannot be silently removed.

Rooms are `coaching:<booking_id>:one_on_one`. The channel derives host/guest from
the booking, rejects other modes and unknown/malformed booking IDs, and allows
admission only during the confirmed appointment's start/end interval while the
coach is approved. Course enrollment gives no coaching permission. Cancellation
broadcasts a booking change and closes connected channels; end timers and
periodic admission checks also close expired/revoked sessions. The existing SFU
cleanup closes published tracks. No coaching namespace falls through to the
legacy free/demo-room role path.

The Flutter dashboard and protected `/#/coaching` route provide directory
search, full profile/availability, booking, appointment history/cancellation,
coach profile/availability management, and admin approval. Admin invitations has
a link to Coaching. Timestamps display in the browser's local timezone and are
submitted with explicit UTC offsets. Appointment lists refresh every 30 seconds
and manually. The coach editor preserves unsaved text during refresh.

`live_configured` reports provider credential availability, not live presence or
provider health. Booking works while video is unconfigured; joining remains
disabled until video is configured and the appointment is in its allowed window.
No external invitation emails are sent by this flow. Cloudflare configuration is
still required to exercise actual audio/video.

Verification covers profile ownership/approval, booking without courses,
conflicting slots and appointments, cancellation/rebooking, private history,
strict booking-room roles and cancellation disconnect, plus Flutter booking,
search, editing, approval, error handling and regression tests.
