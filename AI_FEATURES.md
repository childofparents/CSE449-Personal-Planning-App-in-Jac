# AI ideas for Cadence

These features are proposed, not implemented. The current planner needs no AI key.

## Best first additions

1. **Friday shift screenshot import.** Photograph the manager's next-week schedule. Extract only your shifts, ask which week/name ambiguous entries refer to, and show editable dates/times before saving. Default Evergreen Plymouth, support weekends, and never convert “about two shifts” into invented dates. This solves a recurring problem specific to this planner.
2. **Natural-language quick capture.** Type or dictate “Study for 45 minutes Saturday morning” or “Trivia Thursday at 7.” Return a task or proposed event with explicit duration, timezone, and location candidates. Ask about missing information instead of silently guessing. Voice permissions and transcription would be a separate opt-in capability.
3. **Explainable replanning after shifts arrive.** Suggest moving flexible work around confirmed shifts while protecting classes, weekday gym, travel, and free time. Show a before/after diff and explain every move. Confirm the full plan before writing; a transactional batch endpoint and stale-revision checks must be built first.

## Other useful mobile features

| Idea | Example | Required grounding |
| --- | --- | --- |
| Campus-aware gym suggestions | Recommend Hadley before AAS, or NCRB on a North Campus day | Confirmed destination and route/travel data; never reuse the 10-minute Hadley walk for NCRB |
| Event flyer capture | Turn a student-org flyer into a reviewed event draft | Extracted source text, date/year clarification, chosen Places match |
| Assignment breakdown | Split a project into small, editable work sessions | User's deadline, estimated effort, available gaps; estimates labelled as estimates |
| “What fits now?” | Offer one task that fits a 35-minute gap | Actual upcoming events, travel buffer, task duration and preferences |
| Daily briefing | Explain today's classes, gym, shift, and one achievable priority | Saved agenda with event IDs; avoid inventing commitments |
| Schedule questions | “Can I attend trivia after my shift Friday?” | Actual published shift, event time, travel requirement and server conflict checks |
| Weekly balance reflection | Compare planned gym, completed work, and unfilled time | Recorded completions; do not equate planned time with actual attendance |

## How all four components contribute

- **Server:** owns AI calls, private provider credentials, authorized retrieval, timezone calculations, proposal validation, and persistence. One scheduling rule implementation serves all interfaces.
- **Web:** shows a full-week comparison and lets you review/edit proposed changes.
- **Mobile:** captures text/photos/voice and helps execute today's plan; every AI proposal is editable before confirmation.
- **CLI (still planned):** queries the same saved plan, captures tasks quickly, and prints proposal/conflict details as text or JSON. It must call the running API rather than create another graph store.

An impressive demonstration: import Friday's schedule on the phone → review proposed adjustments on web → accept the changes → inspect the same updated weekend from the CLI → complete a task on mobile and verify completion elsewhere after refresh.

## Implementation boundary

Use typed Jac request/proposal structures: operation, existing record ID, revision, proposed start/end, timezone, place ID, explanation, and source evidence. Treat model output as untrusted draft data. Validate permissions, IDs, dates, duration, category/kind compatibility, overlaps, and revisions on the server before saving. Use a proposal ID/idempotency key to avoid double application. Preserve the original plan if any step fails.

Only send the minimum selected planner context to a configured AI provider. Photo uploads and voice recording should be user initiated, with clear handling/retention choices. A model must not mark tasks complete, publish a shift schedule, or move confirmed events without the user's review. Keep deterministic scheduling rules available when the model is unavailable.

Evaluate with representative cases: unpublished Friday schedule, weekend shift, ambiguous screenshot date, NCRB travel before a central-campus lecture, overnight event, daylight-saving transition, overlapping proposals, and stale edits made from web. Measure valid proposals and user corrections, not just fluent explanations.
