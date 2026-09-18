"""Browser preview keeps its session in this tab only."""
def:pub initialServer() -> str { return window.location.origin; }
async def:pub readSession() -> any { return JSON.parse(sessionStorage.getItem("cadence-mobile") or "null"); }
async def:pub writeSession(value: any) -> None { sessionStorage.setItem("cadence-mobile",JSON.stringify(value)); }
async def:pub clearSession() -> None { sessionStorage.removeItem("cadence-mobile"); }

