"""Client-side date formatting, preview fixtures, and authenticated HTTP boundary."""
import from "luxon" { DateTime }

def:pub today() -> str {
    return DateTime.now().setZone("America/Detroit").toISODate();
}

def:pub dateOf(value: str) -> any {
    return DateTime.fromISO(value, {"zone": "America/Detroit"});
}

def:pub monday(value: str) -> str {
    return dateOf(value).startOf("week").toISODate();
}

def:pub shift(value: str, days: int) -> str {
    return dateOf(value).plus({"days": days}).toISODate();
}

def:pub label(value: str, pattern: str) -> str {
    return dateOf(value).toFormat(pattern);
}

def:pub clock(value: str) -> str {
    return dateOf(value).toFormat("h:mm a");
}

def:pub stamp(day: str, time: str) -> str {
    return dateOf(day + "T" + time).toISO();
}

def:pub minute(value: str) -> int {
    d = dateOf(value);
    return d.hour * 60 + d.minute;
}

def:pub tone(category: str) -> str {
    if category == "social/campus" {
        return "social";
    }
    return category;
}

def:pub uid() -> str {
    return str((crypto as any).randomUUID());
}

async def:pub request(path: str, payload: any, token: str = "") -> any {
    response = await fetch(
        path,
        {
            "method": "POST",
            "headers": {
                "Content-Type": "application/json",
                "Authorization": "Bearer " + token
            },
            "body": JSON.stringify(payload)
        }
    );
    body: any = await response.json();
    if not response.ok or body.ok == False {
        raise Exception(
            body.error?.message
                or body.detail
                or "Request failed. Please sign in or try again."
        );
    }
    return body;
}

async def:pub api(operation: str, payload: any, token: str) -> any {
    body = await request("/api/planner/function/" + operation, payload, token);
    result = body.data?.result;
    if not result or not result.ok {
        message = result?.error?.message or "The server could not save this change.";
        details = result?.error?.details;
        if Array.isArray(details) and details.length > 0 {
            message = message
                + ": "
                + details.map(lambda (d: any) { return d.title or d.code; }).join(", ");
        }
        raise Exception(message);
    }
    return result.data;
}

def:pub previewTasks() -> any {
    return [
        {
            "id": "sample1",
            "title": "Build my Jac planning dashboard",
            "category": "academics",
            "duration_minutes": 60,
            "completed": False,
            "revision": 1,
            "block_ids": []
        },
        {
            "id": "sample2",
            "title": "Plan a catch-up with friends",
            "category": "social/campus",
            "duration_minutes": 60,
            "completed": False,
            "revision": 1,
            "block_ids": []
        },
        {
            "id": "sample3",
            "title": "Grocery run for the week",
            "category": "personal",
            "duration_minutes": 45,
            "completed": False,
            "revision": 1,
            "block_ids": []
        }
    ];
}

def:pub previewWeek(day: str) -> any {
    first = monday(day);
    days: any = [];
    for i in range(7) {
        ds = shift(first, i);
        blocks: any = [];
        seeds: any = [
            ["eecs", "EECS 449", [0, 2], "13:30", "15:20", "CHRYS 133"],
            ["org", "ORGSTUDY 201", [0, 2], "16:00", "17:20", "EHB 844"],
            ["aas", "AAS 254", [1, 3], "11:30", "12:50", "AHB"],
            ["org-disc", "ORGSTUDY discussion", [3], "16:00", "16:50", "WEIS 755"],
            ["aas-disc", "AAS 254 discussion", [4], "09:00", "09:50", "TMCG 020"]
        ];
        for item in seeds {
            if item[2].includes(i) and ds >= "2026-08-31" and ds <= "2026-12-11" {
                blocks.push(
                    {
                        "id": item[0] + ds,
                        "title": item[1],
                        "category": "academics",
                        "kind": "class",
                        "start": stamp(ds, item[3]),
                        "end": stamp(ds, item[4]),
                        "location": item[5],
                        "revision": 0
                    }
                );
            }
        }
        if i < 5 {
            blocks.push(
                {
                    "id": "gym" + ds,
                    "title": "Gym & reset",
                    "category": "gym",
                    "kind": "gym",
                    "start": stamp(ds, "10:00" if i == 4 else "09:00"),
                    "end": stamp(ds, "12:00" if i == 4 else "10:45"),
                    "location": "Hadley Rec Center · suggested",
                    "revision": 1
                }
            );
        }
        if i == 1 or i == 3 {
            blocks.push(
                {
                    "id": "walk" + ds,
                    "title": "Walk to AHB",
                    "category": "travel",
                    "kind": "travel",
                    "start": stamp(ds, "10:45"),
                    "end": stamp(ds, "10:55"),
                    "location": "10 min · gym → AHB",
                    "revision": 1
                }
            );
        }
        days.push(
            {
                "date": ds,
                "blocks": blocks,
                "gym": {"required": i < 5, "planned": i < 5, "completed": False}
            }
        );
    }
    return {
        "days": days,
        "warnings": [],
        "work_weeks": [
            {
                "week_start": first,
                "published": False,
                "revision": 0,
                "publication_date": shift(first, -3)
            }
        ]
    };
}


# Clip multi-day intervals to their local calendar day.
def:pub eventStyle(block: any, day: str, firstHour: int) -> any {
    midnight = dateOf(day).startOf("day");
    start = max(0.0, dateOf(block.start).diff(midnight, "minutes").minutes);
    end = min(1440.0, dateOf(block.end).diff(midnight, "minutes").minutes);
    return {
        "top": str((start - firstHour * 60) * 4 / 60) + "rem",
        "height": str(max(22.0, (end - start) * 64 / 60 - 4) / 16) + "rem"
    };
}

def:pub calendarBounds(blocks: any) -> any {
    first = 8;
    last = 22;
    for b in blocks {
        a = dateOf(b.start);
        z = dateOf(b.end);
        if a.toISODate() != z.toISODate() {
            first = 0;
            last = 24;
        } else {
            first = min(first, a.hour);
            last = max(last, z.hour + 1);
        }
    }
    return {"start": first, "end": min(24, last)};
}

def:pub trapFocus(e: any) -> None {
    if e.key != "Tab" {
        return;
    }
    elements = e.currentTarget.querySelectorAll(
        "button:not([disabled]), input:not([disabled]), select:not([disabled])"
    );
    first = elements[0];
    last = elements[elements.length - 1];
    if e.shiftKey and document.activeElement == first {
        e.preventDefault();
        last.focus();
    } elif not e.shiftKey and document.activeElement == last {
        e.preventDefault();
        first.focus();
    }
}
