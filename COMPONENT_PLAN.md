# Four-component feature plan

Status (September 18, 2026): server, web, native mobile screens, and CLI are implemented.
Mobile iOS/Android JavaScript bundles compile; installable packaging/device testing is deferred for a later extra-credit enhancement. See [README.md](README.md) for the running API and tested behavior.
The remaining sections preserve the broader component design.
Personal schedule and confirmed preferences: [PLANNER_BRIEF.md](PLANNER_BRIEF.md).

## Product workflow

Plan the week on the web, follow and adjust the day on the phone, and capture
tasks from the terminal. One server persists the plan and applies its rules.

## Responsibilities and first-release features

| Component | Primary purpose | First release |
| --- | --- | --- |
| Server | Own data and scheduling rules | Persistent tasks, dated blocks, recurring classes, travel blocks, gym preferences, date exceptions, day/week reads, conflict checks, completion updates |
| Web | Plan and review the week | Weekly calendar, unscheduled task list, add/edit task form, schedule/move block form, category colors and text labels, conflict explanations, weekday gym coverage, daily detail view |
| Mobile | Follow and adjust today's plan | Today timeline, current/next activity with location, travel departure time, quick task capture, mark complete, reschedule a task block through the same validation |
| CLI | Capture and inspect quickly | Add/list/complete tasks, view today or a selected day, schedule a task, inspect conflicts, readable text and optional JSON output |

Web starts with explicit time-entry forms; drag-and-drop is a later convenience.
Mobile must run as a mobile app connected to the backend, beyond merely shrinking
the web calendar. Select the device platform before its packaging milestone.

## What stays centralized

- IDs, records, persistence, and all authoritative scheduling decisions live on
  the service. Clients never keep independent authoritative planner databases.
- Shared categories: academics, gym, social/campus, personal, and travel.
  Events can have a subtype such as friends, school event, or student organization.
- All interfaces use the same user identity and backend. Request context selects
  the user's data; clients do not choose arbitrary owners in mutation payloads.
- A task can exist without a time block and can have multiple work sessions.
  Completing a session does not automatically complete the whole task.
- Classes and fixed events occupy time but need not be completed like tasks.
- Gym is required each weekday; an individual reservation may move. Show planned
  gym coverage separately from completed gym visits.
- Travel has an origin, destination, and duration. Tuesday/Thursday Hadley-to-AHB
  takes 10 minutes; NCRB visits need their own route times; Friday discussion-to-gym follows the user's stated routine.
  Unknown routes remain unset or visibly estimated, never silently zero.
- Store instants consistently and render in America/Detroit; expand weekly
  recurrence in local time so daylight saving changes preserve class clock times.
- Seed class meetings with their already-adjusted end times exactly once. Honor
  semester bounds and date exceptions. Re-running setup must not duplicate them.

## Scheduling behavior

The server requires an end after a start and checks actual occupied intervals,
including explicit travel. Back-to-back intervals do not overlap, but travel may
make the transition infeasible. Reject overlaps when creating/moving a block and
return the conflicting block IDs and times. Keep the previous saved block intact
when a move fails. Any later intentional overlap override must be explicit.

Moving a gym block must not silently delete its travel block or leave old travel
times behind: update linked travel in the same operation, or request a new route
when the destination changes. Warn about missing weekday gym reservations without
blocking unrelated task capture. Do not count an unscheduled gym task as coverage.

For recurring events, distinguish editing one occurrence from editing the series.
Start with date-specific cancellations/moves and preserve the original series.

## Proposed service operations

Names below are a design contract, not existing Jac commands or endpoints.

| Operation | Purpose |
| --- | --- |
| `create_task`, `update_task`, `list_tasks`, `complete_task`, `remove_task` | Manage task records; setting completed twice has the same result |
| `get_day`, `get_week` | Return dated classes, task sessions, events, travel, and gym coverage |
| `create_block`, `move_block`, `remove_block` | Save an interval or change it after authoritative validation |
| `check_schedule` | Explain overlaps, missing travel information, and missing gym coverage |
| `get_preferences`, `update_preferences` | Read/change gym and scheduling preferences |
| `set_occurrence_exception` | Cancel or move one recurring class/event occurrence |

Return stable IDs and record revisions. Mutations check the revision being edited
so a stale phone screen cannot overwrite a newer web edit silently. A conflict
response asks the client to reload; it does not claim the change was saved.

## Integration and synchronization

Web, mobile, and CLI call the same authenticated Jac REST functions. The service owns
graph nodes; boundary objects/enums carry response data to consumers. Importing
the same local helper in two apps does not share runtime state or persistence.

For the first release, reload after successful mutations and on returning to the
app, with a manual refresh control. Changes made elsewhere become visible on the
next fetch. Do not promise live push synchronization. Show loading/network errors
and preserve unsaved input; never report a failed server write as completed.
Offline write queues and push notifications are later enhancements.

## Proposed Jac workspace

```text
jac.toml              # default-app = web; declare planner, web, mobile, cli
core/planner.jac      # service entry: public planning operations
core/models.jac       # server-owned data model
core/scheduling.jac   # validation and recurrence logic
web/main.jac          # weekly planning interface
mobile/main.jac       # mobile daily interface
cli/main.jac          # terminal commands
```

Declare `planner` as `service`, `web` as `web-app`, `mobile` as `mobile`, and `cli`
as `cli`. Each entry-point uses dotted module notation, such as `core.planner`.
The installed Jac 0.37.11 `jac guide jac-apps` documents that `jac run web`
colocates service apps; defaulting to web should meet the root `jac run` requirement.
Verify generated configuration with `jac run --show` when scaffolding.

CLI reaches the same running service as web/mobile through its saved server origin or --server/CADENCE_SERVER. It imports no graph helpers and creates no independent planner store. See README for commands, JSON output, and authentication.
A physical phone needs a reachable backend address, not the phone's localhost.

## Incremental build order and acceptance checks

1. **Shared task workflow:** scaffold workspace, persist task creation/listing/
   completion in the service, and expose a minimal web list. Restart the server
   and verify the task survives.
2. **CLI integration:** create a task from CLI and see it in web after refresh;
   complete it from web and observe completion from CLI against the same server.
3. **Weekly scheduling:** add the confirmed classes, dated task blocks, recurrence
   exceptions, travel, and gym coverage. Verify Tuesday/Thursday's gym-to-class
   transition; reject an overlapping block without changing saved data.
4. **Mobile integration:** show the same day and complete/reschedule tasks on a
   phone or emulator. Verify those changes from web and CLI. Check stale-edit
   handling and visible errors when the backend is unavailable.
5. **Polish and submission:** category presentation, helpful empty states, setup
   documentation, and a fresh-checkout run of all four components.

Integration demo: add an academic task with CLI, assign it an open afternoon slot
on web, complete it from mobile, and verify its saved status from CLI after a
server restart. Separately demonstrate a rejected class overlap and five weekday
gym reservations with the correct travel routes.

## Later enhancements

After the four-component workflow works: drag-and-drop, free-slot suggestions,
weekly planned/completed time summaries, reminders, and AI task breakdowns or
rescheduling proposals. Suggestions require user acceptance before changing a
plan. These are optional ideas, not requirements from the user or assignment.

## References

- Assignment: https://github.com/marsninja/CSE449-F26/blob/main/extra-credit-1.md
- Latest documentation: https://jaclang.org/docs/latest
- Compiler-matched architecture guidance: `jac guide jac-apps` (Jac 0.37.11).
