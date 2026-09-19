"""Terminal views and strict Detroit-local timestamp input."""
import datetime as dt;
import re;
import from zoneinfo { ZoneInfo }
glob TZ = ZoneInfo("America/Detroit");

def today() -> str {
    return dt.datetime.now(TZ).date().isoformat();
}

def date_value(value: str) -> str {
    if value == "today" {
        return today();
    }
    if dt.date.fromisoformat(value).isoformat() != value {
        raise ValueError("Use a YYYY-MM-DD date.");
    }
    return value;
}

def instant(value: str) -> str {
    parsed = dt.datetime.fromisoformat(value);
    if "T" not in value and " " not in value {
        raise ValueError("Use YYYY-MM-DDTHH:MM, optionally with a UTC offset.");
    }
    if parsed.tzinfo is not None {
        return parsed.isoformat();
    }
    a = parsed.replace(tzinfo=TZ, fold=0);
    b = parsed.replace(tzinfo=TZ, fold=1);
    if a.astimezone(dt.timezone.utc).astimezone(TZ).replace(tzinfo=None) != parsed {
        raise ValueError(
            "That local time does not exist during the daylight-saving change. Supply a valid time."
        );
    }
    if a.utcoffset() != b.utcoffset() {
        raise ValueError(
            "That local time occurs twice. Supply an explicit offset, for example -04:00 or -05:00."
        );
    }
    return a.isoformat();
}

def local(value: str) -> any {
    return dt.datetime.fromisoformat(value).astimezone(TZ);
}

def safe(value: any) -> str {
    # Keep server/user text from emitting terminal escape sequences or fake lines.
    return re.sub(r"[\x00-\x1f\x7f-\x9f]", " ", str(value));
}

def task_text(tasks: list) -> str {
    if not tasks {
        return "No matching tasks.";
    }
    lines = [];
    for t in tasks {
        mark = "done" if t["completed"] else "open";
        lines.append(
            f"[{mark}] {safe(t['title'])}  |  {t['category']}  |  {t[
                'duration_minutes'
            ]} min"
        );
        lines.append(
            f"  ID {t['id']}  rev {t['revision']}  sessions {len(
                t.get('block_ids', [])
            )}"
        );
    }
    return "\n".join(lines);
}

def agenda_text(data: dict) -> str {
    days = data["days"];
    lines = [f"CADENCE  {days[0]['date']} to {days[-1]['date']}  |  America/Detroit"];
    for day in days {
        date = dt.date.fromisoformat(day["date"]);
        lines.append("\n" + date.strftime("%A %b %d"));
        if not day["blocks"] {
            lines.append("  No events. Room to breathe.");
        }
        for b in day["blocks"] {
            start = local(b["start"]);
            end = local(b["end"]);
            a = start.strftime("%H:%M")
                if start.date().isoformat() == day["date"]
                else start.strftime("%b %d %H:%M");
            z = end.strftime("%H:%M")
                if end.date() == start.date()
                else end.strftime("%b %d %H:%M");
            lines.append(
                f"  {a}–{z}  {safe(b['title'])}  [{b['category']}/{b['kind']}]"
            );
            if b.get("location") {
                lines.append("    " + safe(b["location"]));
            }
            lines.append(f"    ID {b['id']}  rev {b['revision']}");
        }
        if day["gym"]["required"] {
            lines.append(
                "  Gym: " + ("planned" if day["gym"]["planned"] else "not yet planned")
            );
        }
    }
    for w in data.get("work_weeks", []) {
        status = "published"
            if w["published"]
            else "awaiting publication on " + w["publication_date"];
        lines.append(
            f"\nRestaurant schedule for {w['week_start']}: {status} (rev {w[
                'revision'
            ]})"
        );
    }
    warnings = data.get("warnings", []);
    lines.append(
        f"\nPlanning notes: {len(warnings)} | Conflicts: {len(
            data.get('conflicts', [])
        )}"
    );
    names: dict = {
        "missing_gym": "Plan a gym visit",
        "travel_unverified": "Check travel time",
        "outside_availability": "Outside preferred hours",
        "travel_buffer_short": "Travel buffer may be too short"
    };
    for w in warnings {
        lines.append(
            "  "
                + str(names.get(w["code"], w["code"]))
                + " "
                + w.get("date", "")
                + " "
                + w.get("block_id", "")
        );
    }
    return "\n".join(lines);
}
