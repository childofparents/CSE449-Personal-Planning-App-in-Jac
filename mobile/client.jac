"""The mobile app is a client of the existing authenticated planner, never another graph."""
import from ..shared.http { request }
def:pub normalizeServer(value: str) -> str {
    clean: any = value.strip();
    while clean.endsWith("/") {
        clean = clean.slice(0, -1);
    }
    if not clean.startsWith("http://") and not clean.startsWith("https://") {
        raise Exception("Use a complete http:// or https:// server address.");
    }
    return clean;
}

async def:pub call(base: str, operation: str, payload: any, token: str) -> any {
    body = await request(base + "/api/planner/function/" + operation, payload, token);
    result = body.data.result if body.data else None;
    if not result or not result.ok {
        problem: any = result.error if result and result.error else {};
        message = problem.message or "Could not load your planner. Try refreshing.";
        details = problem.details;
        if Array.isArray(details) {
            message += ": "
                + details.map(lambda (d: any) { return d.title or d.code; }).join(", ");
        }
        raise Exception(message);
    }
    return result.data;
}
