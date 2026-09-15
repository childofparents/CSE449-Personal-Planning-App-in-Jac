# CSE449-F26 Assignment 1: Personal Planning App in Jac
## Beini Lan | UMID: 12374752

# A Personal Planning App Developed in Jac
Cadence balances semester classes, daily tasks, gym, travel, social plans, and on-call restaurant shifts in a weekly planning dashboard. Built in Jac.


# Cadence — web dashboard for personal planning

A Jac planning service for my Fall 2026 classes, work shifts, tasks, gym, travel, and personal/social activities. The authenticated server and web dashboard are implemented; mobile and CLI interfaces remain future components. No AI API key is needed.

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

The default binding is localhost. Before enabling access from other devices, configure deployment authentication/TLS and change Jac's bootstrap admin password in its admin portal. A phone will eventually use the computer's reachable address.

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
  automatic scheduling, notifications, and mobile/CLI apps are not implemented.

`web/main.jac` contains the reactive interface and forms; `web/support.jac` handles
client date formatting, clearly separated preview fixtures, and authenticated REST
calls; `web/global.css` contains responsive styling; `web/locations.jac` handles Google Places and map previews. All stored planning logic
remains in `core/`. No anonymous planner endpoints were introduced.

Design inspiration: [Routine](https://routine.co/) for the task-and-calendar workspace
and [Denis Nzioki's dashboard reference](https://www.figma.com/community/file/1375949888965696148/task-management-dashboard) for violet accents and dashboard cards. This is an original implementation, not a copied Figma template. Icons: lucide-react. Fonts: DM Sans and Manrope (Google Fonts, with local sans-serif fallbacks).

Check/build the web app:

```sh
jac check --app web
jac build --as client web
```

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

The remaining assignment milestones are the mobile app and CLI. Root `jac run` starts the implemented web UI and service.
