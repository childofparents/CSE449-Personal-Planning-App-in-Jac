"""Client-side date formatting, preview fixtures, and authenticated HTTP boundary."""
import from ..shared.planning { dateOf }
import from ..shared.http { request }

def:pub tone(category: str) -> str {
    if category == "social/campus" {
        return "social";
    }
    return category;
}

def:pub uid() -> str {
    return str((crypto as any).randomUUID());
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
