# Live Streaming (WebRTC via Cloudflare Realtime SFU)

Real-time video sessions for **classroom**, **1-on-1**, and **coaching**. Media is
fanned out by **Cloudflare Realtime SFU**; NAT traversal uses **Cloudflare TURN**;
signaling + presence run over **Phoenix Channels**. This supersedes the (never-built)
Membrane plan in `docs/04_media_streaming.md` for live capture.

> Status: v1. Feature-gated behind config — with no Cloudflare Realtime credentials
> it degrades cleanly (the channel replies `configured: false`, the app shows a
> "Live belum aktif" screen). No live e2e test runs in CI (see "Verification").

## Topology

One **SFU session + one `RTCPeerConnection` per participant**. Each participant
publishes their tracks once (client = offerer) and pulls every other participant's
tracks (SFU = offerer) on the *same* PeerConnection. The SFU handles fan-out, so a
classroom scales without a mesh. The **App Secret never leaves the server** —
`JosjobWeb.LiveRoomChannel` proxies every SFU call; the client only ever receives
short-lived ICE servers and SDP.

```
Flutter (flutter_webrtc)                     Elixir                         Cloudflare
  RTCPeerConnection  ──push(sfu:*)──►  LiveRoomChannel ──Req(Bearer)──►  Realtime SFU  (rtc.live.cloudflare.com)
       ▲  presence_state/diff  ◄── Phoenix.Presence          └────────►  Realtime TURN (ICE credentials)
```

**Discovery** is Presence: each participant's meta carries `sfu_session_id` + the
list of `tracks` they published (`<participantId>:mic|cam|screen`). A subscriber
watches presence diffs and pulls the trackNames it doesn't have yet (batched into
one `tracks/new` call → one renegotiation). Late joiners and leaves fall out for free.

## Where the code lives

| Concern | Location |
|---|---|
| Provider (SFU + TURN HTTP client) | `apps/josjob_ms` — `JosjobMs.Realtime` facade → `JosjobMs.CloudflareRealtime` |
| Signaling channel + presence | `apps/josjob_web` — `JosjobWeb.LiveRoomChannel` (`live_room:*`), `JosjobWeb.Presence` |
| Flutter client | `apps/josjob_fe/lib/live/` — models, `signaling_client.dart`, `live_session_controller.dart`, part-based call UI |
| Entry point | Dashboard → **Live Coaching** → "Start a live session" → `LiveCallPage` |

Realtime lives beside Cloudflare Stream/VOD in the media-streaming app `josjob_ms`
(a leaf app), which `josjob_web` already depends on — no umbrella cycle. The realtime
facade `JosjobMs.Realtime` is kept separate from the Stream facade `JosjobMs` so their
`configured?/0` don't collide.

## Configuration

Create a **Realtime App** (SFU) and a **TURN key** in the Cloudflare dashboard
(Realtime), then set in `envs/.env` (read by `config/runtime.exs`):

```
CLOUDFLARE_REALTIME_APP_ID=...        # SFU app id
CLOUDFLARE_REALTIME_APP_SECRET=...    # SFU app secret (server-side only)
CLOUDFLARE_TURN_KEY_ID=...            # TURN key id
CLOUDFLARE_TURN_TOKEN=...             # TURN key API token (server-side only)
```

Verify: `iex> JosjobMs.Realtime.configured?()` and `JosjobMs.Realtime.turn_configured?()` → `true`.
The Flutter web client derives the socket URL from `API_BASE_URL`
(`--dart-define`), swapping `http`→`ws`.

## How to test live

Requires the credentials above + two clients.

1. Backend: `mix phx.server`.
2. Frontend (web): `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000`
   (WebRTC needs a secure context — `localhost` is exempt; production must be HTTPS).
3. Sign in, go to **Dashboard → Live Coaching → Start a live session** and pick a mode.
4. Open the app in a second browser/profile, sign in as another user, click the
   **same** mode button (shared demo rooms: `josjob-1on1-demo` / `josjob-coaching-demo` /
   `josjob-classroom-demo`). Both should see each other's video/audio.

Mobile: Android/iOS are scaffolded with camera/mic permissions (`minSdk 23`,
`NS*UsageDescription`), but are **not built by CI** (CI ships web only) and need
device testing. Screen share is web/desktop-only in v1.

## Verification (CI)

- Backend: `mix compile --warnings-as-errors`, `mix format`, `mix test`
  (`JosjobMs.CloudflareRealtime` with mocked `Req.Test`; `LiveRoomChannel` join/auth/
  presence/gating).
- Frontend: `flutter analyze` (No issues), `dart format`, `flutter test`
  (model + signaling parsing), `flutter build web`.
- A true multi-party call needs live Cloudflare credentials + two clients and is
  **out of CI scope**.

## Known v1 gaps (deliberate, not hidden)

- **`role` (host/guest) comes from the client join payload.** Host commands
  (`host:end/mute/remove`) are therefore spoofable and destructive. The real fix is
  a server-derived role from the `Appointment`/enrollment (`docs/03`, `room_id`).
  Until then, treat host commands as advisory.
- **Any authenticated user can join any `room_id`** (eavesdrop risk on coaching).
  Same follow-up: authorize room membership from the Appointment/enrollment.
- **No media-plane auto-recovery.** A failed PeerConnection surfaces an error; ICE
  restart + session re-create is a follow-up.
- **CF session cleanup is best-effort** (`terminate/2` closes published tracks; there
  is no session-delete endpoint, so Cloudflare GCs the dead PeerConnection).
