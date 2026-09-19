"""HTTP-only planner client and private local login session. No graph imports."""
import os;
import json;
import tempfile;
import from pathlib { Path }
import from urllib.parse { urlsplit }
import from urllib.request { Request, build_opener, HTTPRedirectHandler }
import from urllib.error { HTTPError, URLError }

# Never forward a bearer token through a redirect to a different server.
class NoRedirect(HTTPRedirectHandler) {
    def redirect_request(
        self: any, req: any, fp: any, code: any, msg: any, headers: any, newurl: any
    ) -> any {
        return None;
    }
}

class ClientError(Exception) {
    def __init__(self: any, code: str, message: str, details: any = None) {
        Exception.__init__(self, message);
        self.code = code;
        self.details = details;
    }
}

def session_path() -> any {
    base = os.environ.get("CADENCE_CONFIG_DIR")
        or str(Path.home() / ".config" / "cadence");
    return Path(base) / "session.json";
}

def read_session() -> dict {
    path = session_path();
    if not path.exists() {
        return {};
    }
    try {
        if path.stat().st_mode & 0o077 {
            raise ValueError("Session file permissions must be private (chmod 600).");
        }
        data = json.loads(path.read_text());
        if not isinstance(data, dict) {
            raise ValueError("Invalid session file.");
        }
        return data;
    } except (ValueError, OSError) as e {
        raise ClientError("session", "Cannot read CLI session: " + str(e));
    }
}

def save_session(data: dict) -> None {
    path = session_path();
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700);
    (fd, temp) = tempfile.mkstemp(prefix=".session-", dir=str(path.parent));
    try {
        with os.fdopen(fd, "w") as f {
            json.dump(data, f);
        }
        os.replace(temp, path);
    } finally {
        if os.path.exists(temp) {
            os.unlink(temp);
        }
    }
}

def logout() -> None {
    session_path().unlink(missing_ok=True);
}

def normalize_server(value: str) -> str {
    value = value.strip().rstrip("/");
    parts = urlsplit(value);
    if parts.scheme not in ["http", "https"]
        or not parts.hostname
        or parts.username
        or parts.password
        or parts.query
        or parts.fragment
        or parts.path not in ["", "/"] {
        raise ClientError(
            "server",
            "Use an http:// or https:// server origin without credentials, path, query, or fragment."
        );
    }
    return value;
}

def post(server: str, path: str, payload: dict, token: str = "") -> dict {
    headers = {"Content-Type": "application/json", "Accept": "application/json"};
    if token {
        headers["Authorization"] = "Bearer " + token;
    }
    req = Request(
        server + path, data=json.dumps(payload).encode(), headers=headers, method="POST"
    );
    try {
        with build_opener(NoRedirect()).open(req, timeout=15) as response {
            body = json.loads(response.read());
        }
    } except HTTPError as e {
        message = "HTTP " + str(e.code);
        if e.code in [401, 403] {
            message += ": sign in with 'login' or check your account permissions.";
        } elif e.code == 409 {
            message += ": reload the record before retrying; no automatic retry was made.";
        } elif e.code in [301, 302, 303, 307, 308] {
            message += ": redirects are not followed. Set --server to the final trusted origin.";
        }
        raise ClientError("http", message);
    } except (URLError, TimeoutError, OSError) {
        raise ClientError(
            "connection",
            "Cannot reach the planner at "
                + server
                + ". Start the server or check --server. The request was not retried; refresh before retrying a write."
        );
    } except ValueError {
        raise ClientError(
            "response", "The server returned invalid JSON. Check --server."
        );
    }
    if not isinstance(body, dict) or body.get("ok") == False {
        raise ClientError("response", "The server rejected the request.");
    }
    return body;
}

def api(server: str, token: str, operation: str, payload: dict) -> any {
    if not token {
        raise ClientError(
            "auth",
            "Sign in first with 'login USERNAME', or set CADENCE_TOKEN and --server."
        );
    }
    body = post(server, "/api/planner/function/" + operation, payload, token);
    result = body.get("data", {}).get("result");
    if not isinstance(result, dict) {
        raise ClientError(
            "response", "Unexpected planner response. Check server version and URL."
        );
    }
    if not result.get("ok") {
        error = result.get("error") or {};
        raise ClientError(
            error.get("code", "planner"),
            error.get("message", "Planner rejected the request."),
            error.get("details")
        );
    }
    return result["data"];
}
