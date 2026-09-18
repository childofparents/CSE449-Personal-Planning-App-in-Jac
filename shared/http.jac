"""Shared authenticated JSON transport. Never stores credentials."""
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
            (body.error.message if body.error else "")
                or body.detail
                or "Request failed. Please sign in or try again."
        );
    }
    return body;
}

