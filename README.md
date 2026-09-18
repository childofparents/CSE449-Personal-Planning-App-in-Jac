# CSE449-F26 Assignment 1: Personal Planning App in Jac
## Beini Lan | UMID: 12374752

# Cadence - A Personal Planning App Developed in Jac

A Jac planning service for my Fall 2026 classes, work shifts, tasks, gym, travel, and personal/social activities. The authenticated server, web dashboard, and native mobile interface are implemented; CLI remains a future component. No AI API key is needed.

## Run

Prerequisite: the Jac CLI, tested with **0.37.14** (`jac --version`). Installation:
[official Jac quickstart](https://jaclang.org/docs/latest/quick-guide/).
From this repository's root, install the pinned browser dependencies once:

```sh
jac install
jac run
```

Open the dashboard at [http://127.0.0.1:8000](http://127.0.0.1:8000).
The web app is the default, and Jac colocates the planner service. Open
[API documentation](http://127.0.0.1:8000/docs) for interactive requests.
For live frontend editing use `jac run --dev` (web on port 8000, proxied API on 8001).
To select a different port for the standalone service, put flags **before** the app name:

```sh
jac run --port 8129 planner
```

Jac automatically provisions embedded PostgreSQL on first start; this can require a download. Planning records and accounts persist in the project's `.jac/` data directory. Stop with Ctrl+C and run the same command from the same project to resume. Keep `.jac/` across sessions; do not use `jac clean --all` to restart.
For a backup, stop the server and copy the project together with its `.jac/` directory. Do not run two copies of its embedded database simultaneously.
An external PostgreSQL database can instead be configured with `JAC_DB_URL`.
Runtime data and local credentials are gitignored.

The default binding is localhost. Before enabling access from other devices, configure deployment authentication/TLS and change Jac's bootstrap admin password in its admin portal. A phone uses the computer's reachable address as described below.

## Web dashboard

The signed-out view is an explicit design preview: confirmed class times, suggested
in-gym blocks, and sample tasks. Preview edits are temporary and calendar navigation
resets preview blocks. They are never copied into a signed-in account.

- Sign in with your existing planner username/password, or create a local account.
  The session token is kept in this tab's `sessionStorage`; passwords are not stored.
- Use **Create task**, click a task title to edit it, and check it off when complete.
  The sidebar switches between the calendar, active tasks, and completed tasks.
- Use **Schedule a session**, **Create event**, or an empty calendar slot.
  Dates/times are interpreted in America/Detroit, including daylight saving time.
- Click a calendar block to inspect it or move it. Class moves affect one occurrence.
  Server overlap/revision errors keep the form open and preserve its values.
- Filter by category or search the task list. Task searches leave calendar events visible. Use arrows/Today to navigate and
  Workweek/7 days to switch views (all seven days are visible by default). The time axis expands for out-of-hours blocks;
  the calendar scrolls horizontally on narrow screens.
- Add dated restaurant shifts on any day, including weekends. New shifts default to
  **16:30–21:00** at **Evergreen Plymouth (2771 Plymouth Rd, Ann Arbor, MI 48105)**;
  adjust start/end times to the published schedule. Explicitly mark each week's schedule published.
  Unpublished weeks display their expected Friday publication date.
- Choose **Hadley Rec Center** or **NCRB** for each gym visit, or enter another location.
  The 10-minute **Walk to AHB** suggestion applies to Hadley only; NCRB travel must be supplied separately.
- The roomier desktop layout uses approximately 110% sizing, with an expanded sidebar note.
- Event locations offer Google Places suggestions and a map beside event details when configured below.
  Selected place IDs persist on the server; manually changing the address clears an outdated ID.
- Refresh to fetch changes from other interfaces. Live push updates, drag-and-drop,
  automatic scheduling, notifications, and the CLI are not implemented.

`web/main.jac` contains the reactive interface and forms; `web/support.jac` handles web helpers and authenticated REST calls; `shared/` contains date formatting, preview fixtures, and JSON transport; `web/global.css` contains responsive styling; `web/locations.jac` handles Google Places and map previews. All stored planning logic
remains in `core/`. No anonymous planner endpoints were introduced.

Design inspiration: [Routine](https://routine.co/) for the task-and-calendar workspace
and [Denis Nzioki's dashboard reference](https://www.figma.com/community/file/1375949888965696148/task-management-dashboard) for violet accents and dashboard cards. This is an original implementation, not a copied Figma template. Icons: lucide-react. Fonts: DM Sans and Manrope (Google Fonts, with local sans-serif fallbacks).

Check/build the web app:

```sh
jac check --app web
jac build --as client web
```

## Mobile app — iOS and Android

`mobile/main.jac` is a native Jac **mobUI / React Native (Expo)** app, with a browser preview through React Native Web. It uses the same violet, mint, peach, blue, and gray category palette as the web dashboard, with touch-sized controls, bottom navigation, keyboard-aware forms, and a daily agenda instead of squeezed calendar columns.

Implemented workflows:

- Browse all seven days, move between weeks, jump to today, and filter categories.
- View classes, gym, travel, social plans, personal events, and restaurant shifts.
- Create/edit tasks, search the inbox, complete/reopen tasks, and schedule task sessions. Searching tasks does not filter the agenda.
- Create and move events; moving a class changes one occurrence. Conflicts and stale revisions keep the form open.
- Add weekday or weekend shifts with editable 16:30–21:00 defaults at Evergreen Plymouth; mark a week's schedule published.
- Pick Hadley or NCRB, enter manual locations, open Google Maps, and optionally search Google Places with a map preview in event details.
- Sign in/register against the same planner service as web. Native tokens use Expo SecureStore; the browser preview uses tab sessionStorage. Passwords are never saved.
- Pull to refresh on native, or tap Refresh, to load changes from other interfaces. Preview edits are temporary; authenticated writes persist on the server. Offline editing and push synchronization are not implemented.

### Browser preview (no phone required)

From the repository root:

```sh
jac install
jac run --platform web --port 8120 mobile
```

Open [http://localhost:8120](http://localhost:8120). This runs the mobile screens with a colocated planner service. In **Account**, use the default server URL for this preview, or enter the URL of your already running planner and sign in with the same account. To edit with hot reload, use `jac run --dev --platform web --port 8120 mobile` **instead**. Jac 0.37.14 shares generated Vite configuration between apps: run only one Vite development frontend at a time; stop it before switching between web and mobile development. A static mobile preview can be used alongside web.

### Phone / simulator development

Prerequisites: Jac 0.37.14, Python 3 for the metadata helper, a phone with an Expo Go version compatible with the generated Expo SDK (currently 57), or an iOS simulator / Android emulator. Jac setup downloads the native dependencies. Local iOS builds require macOS with full Xcode and its simulator tools; Android builds require an Android SDK/emulator and the Java toolchain supported by the generated Expo project. See the [Jac native target guide](https://docs.jaseci.org/reference/plugins/jac-client/) and [Expo development setup](https://docs.expo.dev/get-started/set-up-your-environment/).

```sh
jac setup mobile
python3 tools/configure_mobile.py
jac setup mobile
jac run --dev mobile
```

The helper applies Cadence's display name and native identifiers and synchronizes Luxon, because Jac preserves existing generated package metadata. The second setup installs that dependency. Re-run this sequence after regenerating `.jac/mobile-rn`; do not delete the project's database to rebuild the app. The native launcher starts Metro on port 8081 and also attempts the selected platform build (Android by default). Before the Android workflow, review and accept its SDK license interactively with `jac setup --toolchain android`, then configure an emulator/device. For iOS, use `jac run --dev --platform ios mobile` with full Xcode installed. Scan Metro's QR code using Expo Go, or use the displayed emulator/simulator controls. Use a development build if Expo Go does not support the generated SDK.

The mobile **Account → Planner server URL** must point to the shared running service. `localhost` on a physical phone means the phone itself. For local testing, put the computer and phone on the same trusted Wi-Fi network and run the planner in another terminal:

```sh
jac run --host 0.0.0.0 --port 8129 planner
```

Enter `http://YOUR_COMPUTER_LAN_IP:8129` on the phone. Use the same project/database and account as web. On an Android emulator, the host machine is usually `10.0.2.2`; an iOS simulator can use `127.0.0.1`. Use HTTPS for a deployed service. The phone needs connectivity to both Metro and the API during development.

In the app: **My week** opens your daily agenda; choose a day and tap **Create event** or an existing block. **Tasks** provides capture, search, completion, and session scheduling. **Account** manages connection/sign-in. Pull to refresh after editing on web. Restaurant shifts have their own quick-add and publication controls below the agenda.

Native packaging commands (platform toolchains required):

```sh
jac build --platform android mobile
jac build --platform ios mobile
```

Verification: the mobile browser build and iOS/Android Hermes JavaScript exports compile. A signed IPA/APK and physical-device interaction have **not** been verified. Metro startup was verified. On this Mac, full Xcode is unavailable and Android setup stops pending the user's SDK license acceptance, and Jac 0.37.14's bundled Bun/Expo iOS prebuild also reports an Xcode project parsing error. This is a packaging limitation, not a completed device build. The UI can be exercised now through the browser preview; finish device smoke tests before distribution. Avoid native builds while the mobile browser dev server is running, since Jac reuses generated module paths for platform variants.

### Optional mobile Google Places and map thumbnails

The native app uses authenticated server endpoints rather than exposing a server key in the app. Enable **Places API (New)** and **Maps Static API** on a billed Google Cloud project and set a separate server key in the terminal that runs the planner:

```sh
export GOOGLE_MAPS_SERVER_API_KEY='YOUR_SERVER_KEY'
jac run --host 0.0.0.0 --port 8129 planner
```

Restrict this key to those APIs and your server's outbound IP where applicable. Do not put it in source control or frontend build settings. The existing web dashboard's referrer-restricted browser key is configured separately below. Mobile search starts after three characters and requires sign-in; selecting a match saves its place ID and loads a thumbnail. Without configuration, manual locations and Open Maps still work. Live billed Google responses have not been tested. See [Places autocomplete](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete) and [Maps Static](https://developers.google.com/maps/documentation/maps-static/start).

### How the components fit together

| Component | Responsibility / status |
| --- | --- |
| Server | Implemented: authenticated per-user persistence, recurring classes, scheduling conflicts, revisions, shifts, and optional location proxy |
| Web | Implemented: weekly planning and review |
| Mobile | Implemented: native daily planning/capture screens and shared API; device packaging/testing remains |
| CLI | Planned: terminal capture/query/completion against the same REST service |

`shared/planning.jac` shares Detroit date helpers and explicit preview fixtures; `shared/http.jac` shares JSON transport. Neither client owns a separate planner database. Server validation remains authoritative. See [AI_FEATURES.md](AI_FEATURES.md) for proposed AI additions and a demonstration across all four interfaces. AI features are ideas, not enabled functionality.

## Google location search and map setup (optional)

The core planner works without a Google key: you can enter locations manually and open them in Google Maps. Autocomplete and embedded thumbnails require a Google Cloud project with billing enabled and **Maps JavaScript API**, **Places API (New)**, and **Maps Embed API** enabled. See Google's [JavaScript setup](https://developers.google.com/maps/documentation/javascript/cloud-setup) and [Embed setup](https://developers.google.com/maps/documentation/embed/get-started).

Create an HTTP-referrer-restricted browser API key. Permit your local URLs (`http://localhost:8000/*` and `http://127.0.0.1:8000/*`) and your deployed origin if applicable, and restrict the key to those three APIs. Put this in a **gitignored `jac.local.toml`** at the project root:

```toml
[apps.web.client.vite.define]
"globalThis.GOOGLE_MAPS_API_KEY" = '"YOUR_BROWSER_API_KEY"'
```

Restart `jac run` after changing this build-time setting. This is a browser key and is visible in the client bundle; referrer/API restrictions are required, rather than treating it as a server secret. Do not commit your local configuration. Google usage can incur charges according to your Cloud project's settings.

Type at least two characters in an event's Location field, then select a Google match with the mouse or arrow keys/Enter. Suggestions favor Ann Arbor without excluding other places. A Google map appears alongside the event details; the creation form also previews the location. Without a key or if search fails, the form explains the issue and still accepts a typed location. Location lookup does not calculate travel times or automatically suggest where an event should happen; those are future features.

The integration follows [Google's Place Autocomplete Data API](https://developers.google.com/maps/documentation/javascript/place-autocomplete-data). Live Google results and map rendering require a valid configured key and were not verified with a billed Google project. Local verification covers the unconfigured fallback, form interactions, and server place-ID persistence.

## Account and first requests

Planning endpoints require a bearer token. All clients must sign in to the same account to share planning data; the server derives ownership from the request.
There is no owner/user-ID field in planner mutations.

Register once using `POST /user/register` in `/docs`:

```json
{
  "identities": [{"type": "username", "value": "your-username"}],
  "credential": {"type": "password", "password": "choose-your-password"}
}
```

Keep `data.token` from the response. Subsequent sessions can use
`POST /user/login` with:

```json
{
  "identity": {"type": "username", "value": "your-username"},
  "credential": {"type": "password", "password": "choose-your-password"}
}
```

Set `TOKEN` in your terminal to the returned token, then:

```sh
curl -s http://127.0.0.1:8000/function/create_task \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"title":"Finish assignment","category":"academics","duration_minutes":45}'

curl -s http://127.0.0.1:8000/function/get_week \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"day":"2026-09-14"}'
```

Every operation uses `POST /function/<name>` (also available under
`/api/planner/function/<name>`). Jac wraps the planner response:

```json
{
  "ok": true,
  "data": {
    "result": {"ok": true, "data": {"id": "...", "revision": 1}, "error": null}
  }
}
```

Clients must check **both** the HTTP/Jac result and `data.result.ok`.
Domain rejections return `data.result.ok = false` with
`error.code`, `error.message`, and optional `error.details`; HTTP 200 alone does not mean a plan was saved. Codes include `validation`, `not_found`, `overlap`, `stale_revision`, `linked_travel`, and `route_required`. Overlap details identify
conflicting IDs, titles, and UTC times. Runtime transaction contention can also return HTTP 409; reload before retrying an edit.

## Operations

| Operation | Parameters / behavior |
| --- | --- |
| `create_task` | `title`, optional `category`, `duration_minutes` |
| `list_tasks` | Optional `include_completed` (default true); includes linked block IDs |
| `update_task` | `task_id`, `expected_revision`, `changes` containing title/category/duration_minutes/completed |
| `complete_task` | `task_id`, `expected_revision`; sets completion, does not toggle |
| `create_block` | `title`, `start`, `end`; optional category/kind/task_id/location/place_id/subtype/origin/destination/estimated/linked_to |
| `move_block` | `block_id`, `expected_revision`, `start`, `end`, optional `location`/`place_id`; moves linked travel atomically |
| `complete_block` | `block_id`, `expected_revision`, optional `completed` (true); task completion stays independent |
| `remove_block` | `block_id`, `expected_revision`; remove linked travel first |
| `get_day` | `day` as YYYY-MM-DD |
| `get_week`, `check_schedule` | `day`; returns the Monday–Sunday week containing it |
| `get_preferences` | No parameters |
| `update_preferences` | `expected_revision`, `changes`: gym_weekdays/gym_budget_minutes/daily_availability/travel_buffer_minutes |
| `list_recurring_commitments` | Fixed classes and the variable restaurant commitment |
| `set_occurrence_exception` | `series_id`, `occurrence_date`, `expected_revision`, `action`: cancel/move/restore; moves also take start/end and optional location/place_id |
| `list_occurrence_exceptions` | Includes canceled occurrences and their revisions |
| `set_work_week` | Monday `week_start`, `expected_revision`, `published` boolean; shifts are separate dated work blocks |

Use returned revisions on every edit, move, completion, or deletion. New records start at 1; a class occurrence without an exception and an unpublished work week start at 0. Repeating completion with the current revision is a no-op. An old revision always requires a reload. Restoring a class retains its exception revision so an earlier edit cannot silently overwrite it.

## Planning rules

- Categories: `academics`, `gym`, `social/campus`, `personal`, `travel`.
  Block kinds: `session`, `event`, `gym`, `travel`, `work`.
  Use category `personal`, kind `work` for restaurant shifts. Gym and travel kinds must use the matching category.
- Timestamps require an explicit offset, e.g. `2026-09-14T17:30:00-04:00`.
  The server stores/returns UTC and declares `America/Detroit` as the display timezone. End must follow start; a block can span at most seven days.
- Intervals are half-open: adjacent blocks are allowed. Overlaps with classes, events, work, and travel are rejected before saving. Failed moves preserve the previous activity and all its linked travel.
- Five confirmed class series are seeded once per user. Local recurrence honors August 31–December 11, 2026 and daylight saving changes. Effective end times already include the 10-minute adjustment. Breaks/cancellations must be entered as date exceptions; no unconfirmed holiday calendar is inferred.
- Weekday gym coverage counts a dated gym block, never an unscheduled task.
  Planned and completed coverage are separate. The 150-minute total budget, usual 09:00 arrival/10:45 departure, Friday arrival, and direct campus routes are stored as preferences. Gym blocks are manually scheduled; setup does not turn proposed reservations into confirmed appointments.
- Travel is a separate block with explicit origin/destination and occupied time. Set `estimated: true` for an assumed route. Use `linked_to` for the associated activity. Moving an activity shifts inbound travel by the start change and outbound travel by the end change. A destination change requires replacing linked travel first; no return-home trip is invented.
- Day/week reads warn about missing gym, unverified travel, and configured availability/buffer violations. These warnings do not block task capture.
  `daily_availability` is null or `{"start":"08:00","end":"22:00"}`;
  `travel_buffer_minutes` is null (unknown) or an integer. Neither is a hard prohibition against saving a commitment.
- Restaurant weeks default to `awaiting_publication`, with the previous Friday as publication date. Mark publication explicitly and enter actual shifts; a published week can have zero shifts. Nothing copies shifts into later weeks.

## Implementation and verification

`core/planner.jac` owns the authenticated API, `core/models.jac` defines the persistent per-user `Planner` node and seed data, and `core/scheduling.jac` owns time/recurrence/validation rules. The node contains versioned record dictionaries for this small personal dataset. Jac commits changes at the request transaction boundary. Initial seeding explicitly stages the existing root to prevent racing
first requests from creating separate planner nodes. HTTP scalar defaults are normalized for a verified Jac 0.37.12 adapter quirk.

Future interfaces should call this running service with the same token through REST, then reload after successful writes. These endpoints are authenticated plain Jac functions; do not change them to `def:pub` just to enable a cross-app import, since that would permit anonymous access. Clients must not import the local graph helpers to create their own planner database.

```sh
jac check --app planner
python3 -m unittest discover -s tests -v
```

Tests use only Python's standard library plus Jac. They launch an isolated temporary project/database and test real HTTP authentication, isolation, recurrence/DST, overlaps, atomic travel moves, revisions, concurrent writes, work publication, and persistence after stopping/restarting the server.

The remaining assignment milestones are native device verification and the CLI. Root `jac run` starts the implemented web UI and service.
