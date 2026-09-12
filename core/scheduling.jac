"""Pure planning rules. Wire timestamps are offset-aware ISO 8601, stored in UTC."""
import datetime as dt;
import from zoneinfo { ZoneInfo }

glob TZ = ZoneInfo("America/Detroit");
glob CATEGORIES = ["academics", "gym", "social/campus", "personal", "travel"];

def _date(value: str) -> any {
    result = dt.date.fromisoformat(value);
    if result.isoformat() != value {
        raise ValueError("Use a YYYY-MM-DD date");
    }
    return result;
}

def _instant(value: str) -> any {
    result = dt.datetime.fromisoformat(value);
    if result.tzinfo is None {
        raise ValueError("Timestamps require a UTC offset or Z");
    }
    return result.astimezone(dt.timezone.utc);
}

def _interval(start: str, end: str) -> tuple {
    a = _instant(start);
    b = _instant(end);
    if b <= a {
        raise ValueError("End must be after start");
    }
    if b - a > dt.timedelta(days=7) {
        raise ValueError("A block cannot exceed seven days");
    }
    return (a.isoformat(), b.isoformat());
}

def _local(day: str, clock: str) -> str {
    return dt.datetime.fromisoformat(day + "T" + clock).replace(tzinfo=TZ).astimezone(
        dt.timezone.utc
    ).isoformat();
}

def _overlap(a: dict, b: dict) -> bool {
    return a["start"] < b["end"] and b["start"] < a["end"];
}

def _occurrence(series: dict, day: str) -> dict {
    d = _date(day);
    if day < series["first_date"]
        or day > series["last_date"]
        or d.weekday() not in series["weekdays"] {
        raise ValueError("No occurrence of this series on that date");
    }
    return {
        "id": series["id"] + ":" + day,
        "series_id": series["id"],
        "occurrence_date": day,
        "title": series["title"],
        "category": "academics",
        "kind": "class",
        "start": _local(day, series["start_time"]),
        "end": _local(day, series["end_time"]),
        "location": series["location"],
        "revision": 0,
        "completed": False,
        "task_id": "",
        "linked_to": ""
    };
}

def _events(
    series: dict, exceptions: dict, blocks: dict, start: str, end: str
) -> list {
    window = {"start": start, "end": end};
    result = [
        b.copy()
        for b in blocks.values()
        if _overlap(b, window)
    ];
    first = _instant(start).astimezone(TZ).date();
    last = _instant(end).astimezone(TZ).date();
    day = first;
    while day <= last {
        ds = day.isoformat();
        for s in series.values() {
            if s["first_date"] <= ds <= s["last_date"]
                and day.weekday() in s["weekdays"] {
                event = _occurrence(s, ds);
                if event["id"] not in exceptions and _overlap(event, window) {
                    result.append(event);
                }
            }
        }
        day += dt.timedelta(days=1);
    }
    # Moved occurrences can originate outside the queried week.
    for event in exceptions.values() {
        if event["action"] == "move" and _overlap(event, window) {
            result.append(event.copy());
        }
    }
    result.sort(key=lambda (b: dict) -> str { return b["start"]; });
    return result;
}

def _conflicts(candidates: list, existing: list) -> list {
    result = [];
    for i in range(len(candidates)) {
        a = candidates[i];
        for b in existing + candidates[:i] {
            if _overlap(a, b) {
                result.append(
                    {
                        "block_id": a["id"],
                        "conflicting_id": b["id"],
                        "title": b["title"],
                        "start": b["start"],
                        "end": b["end"]
                    }
                );
            }
        }
    }
    return result;
}

def _validate_task(data: dict) -> None {
    if not isinstance(data["title"], str) or not data["title"].strip() {
        raise ValueError("Title is required");
    }
    if len(data["title"]) > 300 {
        raise ValueError("Title must be at most 300 characters");
    }
    if data["category"] not in CATEGORIES {
        raise ValueError("Unknown category");
    }
    if type(data["duration_minutes"]) is not int
        or not 0 < data["duration_minutes"] <= 10080 {
        raise ValueError("Duration must be an integer between 1 and 10080 minutes");
    }
}

def _validate_block(data: dict) -> None {
    if not isinstance(data["title"], str) or not data["title"].strip() {
        raise ValueError("Title is required");
    }
    if data["category"] not in CATEGORIES {
        raise ValueError("Unknown category");
    }
    if data["kind"] not in ["session", "event", "gym", "travel", "work"] {
        raise ValueError("Unknown block kind");
    }
    if (data["category"] == "travel") != (data["kind"] == "travel") {
        raise ValueError("Travel kind and category must match");
    }
    if (data["category"] == "gym") != (data["kind"] == "gym") {
        raise ValueError("Gym kind and category must match");
    }
    (data["start"], data["end"]) = _interval(data["start"], data["end"]);
    for key in ["location", "origin", "destination", "subtype"] {
        if not isinstance(data[key], str) {
            raise ValueError(key + " must be text");
        }
    }
    if data["kind"] == "travel"
        and (not data["origin"].strip() or not data["destination"].strip()) {
        raise ValueError("Travel requires an origin and destination");
    }
}
