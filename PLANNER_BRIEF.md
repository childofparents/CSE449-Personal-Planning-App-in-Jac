# Personal planner: working brief

## User's intended product

Balance Fall 2026 classes and restaurant work shifts with daily tasks and dedicated
time blocks for academics, gym, and social/campus activities (school events,
friends, and student organizations).
Gym is required every Monday through Friday, preferably in the morning, with a
150-minute total time budget including travel. The user describes all three courses as light workload with no exams. Do not infer study-hour quotas or create exam-preparation tasks.

## Reference links

- Course information and updates: https://github.com/marsninja/CSE449-F26
- Assignment repository: https://github.com/childofparents/CSE449-Personal-Planning-App-in-Jac
- Latest Jac documentation: https://jaclang.org/docs/latest
- Day-Planner learning guide: https://jaclang.org/docs/v0.37/tutorials/first-app/build-ai-day-planner
- Provided syntax reference: https://jaclang.org/docs/v0.37/reference/language/syntax-cheatsheet
- Installed compiler checked in this session: Jac 0.37.11.
- Local syntax reference: `jac guide reference/language/syntax-cheatsheet`.

The course repository is the reference to check during course-related work.
No automatic update monitor has been configured.

## Course schedule confirmed by the user

Source: `/Users/HP/Desktop/26F Class Schedule.pdf`.
Semester dates listed: August 31 through December 11, 2026.
Use America/Detroit for local scheduling. Recurrence must eventually account for
breaks, canceled meetings, and other date-specific exceptions.

All classes and discussions finish 10 minutes before their nominal end time.
The effective end times below already include that adjustment; do not subtract
another 10 minutes. The released time supports travel to the next commitment.

| Days | Course / component | Effective time | Room |
| --- | --- | --- | --- |
| Monday, Wednesday | EECS 449 lecture | 1:30-3:20 PM | CHRYS 133 |
| Monday, Wednesday | ORGSTUDY 201 lecture | 4:00-5:20 PM | EHB844 |
| Tuesday, Thursday | AAS 254 lecture | 11:30 AM-12:50 PM | AHB |
| Thursday | ORGSTUDY 201 discussion | 4:00-4:50 PM | WEIS755 |
| Friday | AAS 254 discussion | 9:00-9:50 AM | TMCG020 |

Resolved by explicit user confirmation: EECS 449 meets Monday/Wednesday in
CHRYS 133, nominally 1:30-3:30 PM. This overrides the conflicting syllabus and
course repository entry (1:30-3:00 PM, 1311 EECS) for this personal planner.

## Gym routine and scheduling preferences

User-provided details:

- Required Monday through Friday.
- Budget approximately 150 minutes total: 30 minutes round-trip travel,
  90 minutes training, and 30 minutes showering/getting ready.
- Monday-Thursday: usually arrive around 9:00 AM and leave around 10:45 AM.
- Tuesday/Thursday: the gym is on central campus. Go directly from the gym to
  AAS 254, approximately a 10-minute walk; do not insert a trip home.
- Friday: depart AAS 254 discussion at 9:50 AM and arrive at the gym around
  10:00 AM; this trip starts at class, not home.

Preserve both the usual visit times and the larger planning budget: 9:00-10:45
is 105 minutes, while the stated training/getting-ready budget is 120 minutes.
Do not silently change the user's usual departure to 11:00 AM.

Proposed initial reservations (editable defaults, not user-confirmed exact times):

- Monday/Wednesday: 8:45-11:15 AM, assuming 15 minutes outbound travel and
  reserving the full 150-minute budget. The usual 10:45 departure plus an assumed
  15-minute return leaves 15 minutes of slack within that reservation.
- Tuesday/Thursday: retain the approximate 9:00 AM gym arrival and usual
  10:45 AM departure. Walk to AAS 254 from 10:45-10:55 AM, leaving approximately
  35 minutes before the 11:30 AM lecture. A 15-minute home-to-gym trip is still
  only an assumption. Keep the 150-minute gym budget as a planning preference,
  not a reason to invent return-home travel or fill the remaining time.
- Friday: 9:50 AM-12:20 PM, reserving 150 minutes from the end of discussion,
  with the user-provided approximate 10:00 AM gym arrival.

The Tuesday/Thursday transition is resolved by the user's direct gym-to-class
route. Keep travel origins and destinations explicit when scheduling: Tuesday/
Thursday go gym-to-lecture, Friday goes discussion-to-gym, and a home round trip
must not be assumed for every gym visit. Store travel separately from activity
time so it changes with the day's route.

## Restaurant work commitment

Work recurs approximately two days per week, but the weekdays and shift times
vary. The manager publishes the following week's shift schedule on Friday.
Until then, mark that week's work schedule as awaiting publication; do not assume
fixed weekdays, invent shift times, or copy the previous week's shifts forward.

Once published, enter each shift as a dated commitment with its actual start and
end times, then check conflicts with classes, gym, travel, and other plans.
The recurring commitment represents the ongoing job and approximate weekly
frequency; its individual shifts are scheduled separately for each week.

## Proposed first workflow

1. Show fixed class meetings for a selected week.
2. Add a task with a category and estimated duration.
3. Assign it a time block; flag overlap with existing commitments.
4. Show whether each weekday has a gym block.
5. Mark tasks complete and allow flexible blocks to move.

Start with manual scheduling and visible conflict checks. Automatic suggestions
can follow after the basic workflow works.

## Proposed concepts to implement together

- Task: work or activity to complete; title, category, duration, completion status.
- TimeBlock: a dated start/end interval, optionally linked to a task.
- RecurringCommitment: an ongoing commitment with either a fixed recurring
  schedule (such as classes, with weekdays, times, semester bounds, location,
  and date exceptions) or variable weekly occurrences. Restaurant work is
  approximately two days per week, with next week's dates and times pending
  until the manager publishes them on Friday; store published shifts as dated
  occurrences rather than a fixed weekly time pattern.
- PlanningPreference: weekday gym requirement, 150-minute total gym budget,
  preferred arrival times, daily availability, and travel buffers.

A required activity is not necessarily fixed at a particular clock time.
Keep gym's required frequency separate from whether its scheduled block can move.

## Assignment constraints (from the assignment document)

Individual project due October 5, 2026. Build a persistent server, web frontend,
mobile app, and CLI using Jac, sharing planning data. Ultimately `jac run` at the
repository root must start the web application and server. The README must cover
setup and all interfaces. These are submission requirements, not instructions to
publish or submit work now.

## Current progress

`learning/task_basics.jac` demonstrates an in-memory task and completion state.
It is a learning exercise, not yet the application. This brief records the next
design step; persistence, scheduling, and the four interfaces remain to build.
