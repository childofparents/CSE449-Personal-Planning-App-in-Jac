"""Authenticated planning API. Clients use POST /function/<operation>."""
import datetime as dt;
import from uuid { uuid4 as _uuid4 }
import from copy { deepcopy as _deepcopy }
import from .models { Planner, _preferences, _classes }
import from .scheduling {
    TZ,
    _date,
    _instant,
    _interval,
    _local,
    _occurrence,
    _events,
    _conflicts,
    _validate_task,
    _validate_block
}

def _state() -> Planner {
    states = [root-->][?:Planner];
    if states {
        state = states[0];
        if state.schema_version < 2 {
            prefs = state.preferences.copy();
            defaults = _preferences();
            for key in [
                "gym_locations",
                "work_location",
                "work_default_start",
                "work_default_end",
                "work_possible_weekdays"
            ] {
                prefs[key] = defaults[key];
            }
            routes = _deepcopy(prefs.get("routes", []));
            for route in routes {
                if route.get("origin") == "gym" {
                    route["origin"] = "Hadley Rec Center";
                }
                if route.get("destination") == "gym" {
                    route["destination"] = "Hadley Rec Center";
                }
                if route.get("destination") == "AAS 254 lecture" {
                    route["destination"] = "AHB";
                }
            }
            prefs["routes"] = routes;
            prefs["revision"] += 1;
            state.preferences = prefs;
            state.schema_version = 2;
        }
        return state;
    }
    # Stage the existing root in this transaction as well as the new child.
    # This makes concurrent first-use requests contend on the same persisted row.
    save(root);
    return root ++> Planner(preferences=_preferences(), series=_classes());
}

def _ok(data: any) -> dict {
    return {"ok": True, "data": data, "error": None};
}
def _error(code: str, message: str, details: any = None) -> dict {
    return {
        "ok": False,
        "data": None,
        "error": {"code": code, "message": message, "details": details}
    };
}

def _revision(record: dict, expected: int) -> bool {
    return record["revision"] == expected;
}
def _now() -> str {
    return dt.datetime.now(dt.timezone.utc).isoformat();
}

def create_task(
    title: str, category: str = "personal", duration_minutes: int = 30
) -> dict {
    # Jac 0.37.12's HTTP adapter passes omitted scalar defaults as source strings.
    # Normalize those defaults at the boundary; updates still validate strict types.
    item = {
        "id": str(_uuid4()),
        "title": title.strip(),
        "category": category,
        "duration_minutes": int(duration_minutes),
        "completed": False,
        "revision": 1,
        "created_at": _now()
    };
    try {
        _validate_task(item);
    } except ValueError as e {
        return _error("validation", str(e));
    }
    state = _state();
    tasks = state.tasks.copy();
    tasks[item["id"]] = item;
    state.tasks = tasks;
    return _ok(item);
}

def list_tasks(include_completed: bool = True) -> dict {
    state = _state();
    tasks = [
        t.copy()
        for t in state.tasks.values()
        if include_completed in [True, "True"] or not t["completed"]
    ];
    tasks.sort(key=lambda (t: dict) -> str { return t["created_at"]; });
    for t in tasks {
        t["block_ids"] = [
            b["id"]
            for b in state.blocks.values()
            if b["task_id"] == t["id"]
        ];
    }
    return _ok(tasks);
}

def update_task(task_id: str, expected_revision: int, changes: dict) -> dict {
    state = _state();
    old = state.tasks.get(task_id);
    if old is None {
        return _error("not_found", "Task not found");
    }
    if not _revision(old, expected_revision) {
        return _error("stale_revision", "Reload the task before editing", old);
    }
    if not changes
        or set(changes) - {"title", "category", "duration_minutes", "completed"} {
        return _error(
            "validation",
            "Only title, category, duration_minutes and completed can be updated"
        );
    }
    item = old.copy();
    item.update(changes);
    try {
        _validate_task(item);
        if type(item["completed"]) is not bool {
            raise ValueError("completed must be boolean");
        }
    } except (ValueError, TypeError) as e {
        return _error("validation", str(e));
    }
    item["title"] = item["title"].strip();
    if item == old {
        return _ok(old);
    }
    item["revision"] += 1;
    tasks = state.tasks.copy();
    tasks[task_id] = item;
    state.tasks = tasks;
    return _ok(item);
}

def complete_task(task_id: str, expected_revision: int) -> dict {
    return update_task(task_id, expected_revision, {"completed": True});
}

def _check_candidates(state: Planner, candidates: list, excluded: list) -> list {
    existing = {};
    for c in candidates {
        for b in _events(
            state.series, state.exceptions, state.blocks, c["start"], c["end"]
        ) {
            if b["id"] not in excluded {
                existing[b["id"]] = b;
            }
        }
    }
    return _conflicts(candidates, list(existing.values()));
}

def create_block(
    title: str,
    start: str,
    end: str,
    category: str = "personal",
    kind: str = "event",
    task_id: str = "",
    location: str = "",
    place_id: str = "",
    subtype: str = "",
    origin: str = "",
    destination: str = "",
    estimated: bool = False,
    linked_to: str = ""
) -> dict {
    state = _state();
    item = {
        "id": str(_uuid4()),
        "title": title.strip(),
        "start": start,
        "end": end,
        "category": category,
        "kind": kind,
        "task_id": task_id,
        "location": location
            or (state.preferences["work_location"] if kind == "work" else ""),
        "place_id": place_id,
        "subtype": subtype,
        "origin": origin,
        "destination": destination,
        "estimated": estimated in [True, "True"],
        "linked_to": linked_to,
        "completed": False,
        "revision": 1
    };
    try {
        _validate_block(item);
    } except (ValueError, TypeError) as e {
        return _error("validation", str(e));
    }
    if task_id and task_id not in state.tasks {
        return _error("not_found", "Task not found");
    }
    if linked_to {
        parent = state.blocks.get(linked_to);
        if kind != "travel" or parent is None or parent["kind"] == "travel" {
            return _error(
                "validation", "Only travel can link to an existing activity block"
            );
        }
    }
    conflicts = _check_candidates(state, [item], []);
    if conflicts {
        return _error("overlap", "Block overlaps an existing commitment", conflicts);
    }
    blocks = state.blocks.copy();
    blocks[item["id"]] = item;
    state.blocks = blocks;
    return _ok(item);
}

def move_block(
    block_id: str,
    expected_revision: int,
    start: str,
    end: str,
    location: str | None = None,
    place_id: str | None = None
) -> dict {
    state = _state();
    old = state.blocks.get(block_id);
    if old is None {
        return _error(
            "not_found", "Block not found; use set_occurrence_exception for a class"
        );
    }
    if not _revision(old, expected_revision) {
        return _error("stale_revision", "Reload the block before moving", old);
    }
    if old["linked_to"] {
        return _error("linked_travel", "Move linked travel through its activity block");
    }
    if location == "None" {
        location = None;
    }
    if place_id == "None" {
        place_id = None;
    }
    linked = [
        b
        for b in state.blocks.values()
        if b["linked_to"] == block_id
    ];
    if linked
        and (
            (location is not None and location != old["location"])
            or (place_id is not None and place_id != old.get("place_id", ""))
        ) {
        return _error(
            "route_required",
            "Remove linked travel and supply a new route before changing destination"
        );
    }
    try {
        (start, end) = _interval(start, end);
    } except ValueError as e {
        return _error("validation", str(e));
    }
    start_delta = _instant(start) - _instant(old["start"]);
    end_delta = _instant(end) - _instant(old["end"]);
    item = old.copy();
    item.update({"start": start, "end": end, "revision": old["revision"] + 1});
    if location is not None {
        item["location"] = location;
        if location != old["location"] {
            item["place_id"] = "";
        }
    }
    if place_id is not None {
        item["place_id"] = place_id;
    }
    try {
        _validate_block(item);
    } except (ValueError, TypeError) as e {
        return _error("validation", str(e));
    }
    candidates = [item];
    for b in linked {
        moved = b.copy();
        delta = start_delta if b["end"] <= old["start"] else end_delta;
        moved["start"] = (_instant(b["start"]) + delta).isoformat();
        moved["end"] = (_instant(b["end"]) + delta).isoformat();
        moved["revision"] += 1;
        candidates.append(moved);
    }
    conflicts = _check_candidates(state, candidates, [b["id"] for b in candidates]);
    if conflicts {
        return _error(
            "overlap", "Move rejected; saved blocks are unchanged", conflicts
        );
    }
    blocks = state.blocks.copy();
    for b in candidates {
        blocks[b["id"]] = b;
    }
    state.blocks = blocks;
    return _ok({"block": item, "linked_travel": candidates[1:]});
}

def complete_block(
    block_id: str, expected_revision: int, completed: bool = True
) -> dict {
    state = _state();
    old = state.blocks.get(block_id);
    if old is None {
        return _error("not_found", "Block not found");
    }
    if not _revision(old, expected_revision) {
        return _error("stale_revision", "Reload the block before editing", old);
    }
    completed = completed in [True, "True"];
    if old["completed"] == completed {
        return _ok(old);
    }
    item = old.copy();
    item["completed"] = completed;
    item["revision"] += 1;
    blocks = state.blocks.copy();
    blocks[block_id] = item;
    state.blocks = blocks;
    return _ok(item);
}

def remove_block(block_id: str, expected_revision: int) -> dict {
    state = _state();
    old = state.blocks.get(block_id);
    if old is None {
        return _error("not_found", "Block not found");
    }
    if not _revision(old, expected_revision) {
        return _error("stale_revision", "Reload the block before removing", old);
    }
    linked = [
        b["id"]
        for b in state.blocks.values()
        if b["linked_to"] == block_id
    ];
    if linked {
        return _error("linked_travel", "Remove linked travel first", linked);
    }
    blocks = state.blocks.copy();
    del blocks[block_id];
    state.blocks = blocks;
    return _ok({"removed_id": block_id});
}

def get_preferences() -> dict {
    return _ok(_state().preferences);
}

def update_preferences(expected_revision: int, changes: dict) -> dict {
    state = _state();
    old = state.preferences;
    if not _revision(old, expected_revision) {
        return _error("stale_revision", "Reload preferences before editing", old);
    }
    allowed = {
        "gym_weekdays",
        "gym_budget_minutes",
        "daily_availability",
        "travel_buffer_minutes"
    };
    if not changes or set(changes) - allowed {
        return _error("validation", "Unsupported preference field");
    }
    item = _deepcopy(old);
    item.update(changes);
    try {
        days = item["gym_weekdays"];
        if not isinstance(days, list) or len(set(days)) != len(days) {
            raise ValueError("gym_weekdays must be a unique list");
        }
        for d in days {
            if type(d) is not int or not 0 <= d <= 6 {
                raise ValueError("Weekdays use Monday=0 through Sunday=6");
            }
        }
        budget = item["gym_budget_minutes"];
        if type(budget) is not int or not 1 <= budget <= 1440 {
            raise ValueError("Gym budget must be 1–1440 minutes");
        }
        buffer = item["travel_buffer_minutes"];
        if buffer is not None
            and (type(buffer) is not int or not 0 <= buffer <= 1440) {
            raise ValueError("Travel buffer must be null or 0–1440 minutes");
        }
        availability = item["daily_availability"];
        if availability is not None {
            if not isinstance(availability, dict)
                or set(availability) != {"start", "end"} {
                raise ValueError("Availability requires start/end HH:MM");
            }
            for key in ["start", "end"] {
                value = availability[key];
                if not isinstance(value, str) or len(value) != 5 {
                    raise ValueError("Use HH:MM availability times");
                }
                dt.time.fromisoformat(value);
            }
            if availability["start"] >= availability["end"] {
                raise ValueError("Availability must end after start on the same day");
            }
        }
    } except (ValueError, TypeError) as e {
        return _error("validation", str(e));
    }
    if item == old {
        return _ok(old);
    }
    item["revision"] += 1;
    state.preferences = item;
    return _ok(item);
}

def list_recurring_commitments() -> dict {
    return _ok(
        {
            "classes": list(_state().series.values()),
            "work": {
                "id": "restaurant",
                "pattern": "variable",
                "approximate_days_per_week": 2,
                "publication_weekday": 4,
                "fixed_shifts": []
            }
        }
    );
}

def set_occurrence_exception(
    series_id: str,
    occurrence_date: str,
    expected_revision: int,
    action: str,
    start: str = "",
    end: str = "",
    location: str | None = None,
    place_id: str | None = None
) -> dict {
    state = _state();
    series = state.series.get(series_id);
    if series is None {
        return _error("not_found", "Recurring commitment not found");
    }
    try {
        item = _occurrence(series, occurrence_date);
    } except ValueError as e {
        return _error("validation", str(e));
    }
    old = state.exceptions.get(item["id"], item);
    if not _revision(old, expected_revision) {
        return _error("stale_revision", "Reload this occurrence before editing", old);
    }
    if action not in ["cancel", "move", "restore"] {
        return _error("validation", "Action must be cancel, move or restore");
    }
    item["action"] = "move" if action == "restore" else action;
    item["revision"] = old["revision"] + 1;
    if action == "move" {
        try {
            (item["start"], item["end"]) = _interval(start, end);
        } except ValueError as e {
            return _error("validation", str(e));
        }
        item["location"] = old["location"];
        item["place_id"] = old.get("place_id", "");
        if location is not None and location != "None" {
            item["location"] = location;
            if location != old["location"] {
                item["place_id"] = "";
            }
        }
        if place_id is not None and place_id != "None" {
            item["place_id"] = place_id;
        }
        if not isinstance(item["location"], str)
            or not isinstance(item["place_id"], str) {
            return _error("validation", "Location and place_id must be text");
        }
        if item["place_id"] and not item["location"].strip() {
            return _error("validation", "A Google place requires location text");
        }
    }
    if action != "cancel" {
        conflicts = _check_candidates(state, [item], [item["id"]]);
        if conflicts {
            return _error("overlap", "Occurrence change rejected", conflicts);
        }
    }
    exceptions = state.exceptions.copy();
    exceptions[item["id"]] = item;
    state.exceptions = exceptions;
    return _ok(item);
}

def list_occurrence_exceptions() -> dict {
    return _ok(list(_state().exceptions.values()));
}

def set_work_week(week_start: str, expected_revision: int, published: bool) -> dict {
    try {
        day = _date(week_start);
        if day.weekday() != 0 {
            raise ValueError("week_start must be a Monday");
        }
    } except ValueError as e {
        return _error("validation", str(e));
    }
    state = _state();
    old = state.work_weeks.get(week_start, {"revision": 0});
    if not _revision(old, expected_revision) {
        return _error("stale_revision", "Reload work week before editing", old);
    }
    item = {
        "week_start": week_start,
        "published": published,
        "revision": old["revision"] + 1
    };
    weeks = state.work_weeks.copy();
    weeks[week_start] = item;
    state.work_weeks = weeks;
    return _ok(item);
}

def _read_days(day: str, count: int) -> dict {
    try {
        first = _date(day);
    } except ValueError as e {
        return _error("validation", str(e));
    }
    state = _state();
    last = first + dt.timedelta(days=count);
    events = _events(
        state.series,
        state.exceptions,
        state.blocks,
        _local(day, "00:00"),
        _local(last.isoformat(), "00:00")
    );
    days = [];
    warnings = [];
    for offset in range(count) {
        date = first + dt.timedelta(days=offset);
        ds = date.isoformat();
        window = {
            "start": _local(ds, "00:00"),
            "end": _local((date + dt.timedelta(days=1)).isoformat(), "00:00")
        };
        daily = [
            b
            for b in events
            if b["start"] < window["end"] and window["start"] < b["end"]
        ];
        # A midnight-spanning gym visit counts only on its local start date.
        gym = [
            b
            for b in daily
            if b["kind"] == "gym" and _instant(b["start"]).astimezone(TZ).date() == date
        ];
        required = date.weekday() in state.preferences["gym_weekdays"];
        if required and not gym {
            warnings.append({"code": "missing_gym", "date": ds});
        }
        for b in daily {
            if b["kind"] in ["class", "gym", "work"]
                and not _travel_verified(b, daily) {
                warnings.append(
                    {"code": "travel_unverified", "block_id": b["id"], "date": ds}
                );
            }
            availability = state.preferences["daily_availability"];
            if availability
                and (
                    b["start"] < _local(ds, availability["start"])
                    or b["end"] > _local(ds, availability["end"])
                ) {
                warnings.append(
                    {"code": "outside_availability", "block_id": b["id"], "date": ds}
                );
            }
        }
        buffer = state.preferences["travel_buffer_minutes"];
        if buffer is not None {
            for i in range(1, len(daily)) {
                previous = daily[i - 1];
                current = daily[i];
                if previous.get("location")
                    and current.get("location")
                    and previous["location"] != current["location"]
                    and _instant(current["start"]) - _instant(previous["end"])
                        < dt.timedelta(minutes=buffer) {
                    warnings.append(
                        {
                            "code": "travel_buffer_short",
                            "block_id": current["id"],
                            "previous_id": previous["id"]
                        }
                    );
                }
            }
        }
        days.append(
            {
                "date": ds,
                "blocks": daily,
                "gym": {
                    "required": required,
                    "planned": len(gym) > 0,
                    "completed": len(
                        [
                            b
                            for b in gym
                            if b["completed"]
                        ]
                    )
                        > 0,
                    "budget_minutes": state.preferences["gym_budget_minutes"]
                }
            }
        );
    }
    weeks = {};
    for offset in range(count) {
        date = first + dt.timedelta(days=offset);
        monday = date - dt.timedelta(days=date.weekday());
        key = monday.isoformat();
        status = state.work_weeks.get(
            key, {"week_start": key, "published": False, "revision": 0}
        ).copy();
        status["status"] = "published"
            if status["published"]
            else "awaiting_publication";
        status["publication_date"] = (monday - dt.timedelta(days=3)).isoformat();
        weeks[key] = status;
    }
    return _ok(
        {
            "timezone": "America/Detroit",
            "days": days,
            "warnings": warnings,
            "conflicts": _conflicts(events, []),
            "work_weeks": list(weeks.values())
        }
    );
}

def get_day(day: str) -> dict {
    return _read_days(day, 1);
}
def get_week(day: str) -> dict {
    try {
        date = _date(day);
    } except ValueError as e {
        return _error("validation", str(e));
    }
    return _read_days((date - dt.timedelta(days=date.weekday())).isoformat(), 7);
}

def check_schedule(day: str) -> dict {
    return get_week(day);
}

def _travel_verified(block: dict, daily: list) -> bool {
    location = block.get("location");
    if not location {
        return False;
    }
    previous = [
        b
        for b in daily
        if b["kind"] != "travel" and b["end"] <= block["start"]
    ];
    previous.sort(key=lambda (b: dict) -> str { return b["end"]; });
    prior = previous[-1] if previous else None;
    if prior and prior.get("location") == location {
        return True;
    }
    for travel in daily {
        if travel["kind"] != "travel"
            or travel["end"] > block["start"]
            or travel.get("destination") != location {
            continue;
        }
        if prior
            and (
                travel["start"] < prior["end"]
                or not prior.get("location")
                or travel.get("origin") != prior["location"]
            ) {
            continue;
        }
        return True;
    }
    return False;
}
