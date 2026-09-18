"""Optional Google services. Keys stay on the server; no client chooses an upstream URL."""
import os;
import json;
import re;
import base64;
import from urllib.request { Request, urlopen }
import from urllib.parse { urlencode, quote }

def _key() -> str {
    key = os.environ.get("GOOGLE_MAPS_SERVER_API_KEY", "");
    if not key {
        raise ValueError(
            "Google place search is not configured on this planner server."
        );
    }
    return key;
}

def _place_id(value: str) -> str {
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,256}", value) {
        raise ValueError("Invalid Google place ID");
    }
    return value;
}

def _session(value: str) -> str {
    if not re.fullmatch(r"[A-Za-z0-9_.-]{1,128}", value) {
        raise ValueError("Invalid place search session");
    }
    return value;
}

def _json(url: str, fields: str, payload: dict | None = None) -> dict {
    headers = {
        "X-Goog-Api-Key": _key(),
        "X-Goog-FieldMask": fields,
        "Content-Type": "application/json"
    };
    data = json.dumps(payload).encode() if payload is not None else None;
    with urlopen(Request(url, data=data, headers=headers), timeout=10) as response {
        return json.loads(response.read(1048576));
    }
}

def _search(query: str, session_token: str) -> list {
    if len(query.strip()) < 3 or len(query) > 200 {
        raise ValueError("Search needs 3–200 characters");
    }
    payload = {
        "input": query,
        "sessionToken": _session(session_token),
        "regionCode": "us",
        "locationBias": {
            "circle": {
                "center": {"latitude": 42.2808, "longitude": -83.743},
                "radius": 15000
            }
        }
    };
    body = _json(
        "https://places.googleapis.com/v1/places:autocomplete",
        "suggestions.placePrediction.placeId,suggestions.placePrediction.text.text",
        payload
    );
    return [
        {
            "id": p["placePrediction"]["placeId"],
            "label": p["placePrediction"]["text"]["text"]
        }
        for p in body.get("suggestions", [])
        if "placePrediction" in p
    ];
}

def _select(place_id: str, session_token: str) -> dict {
    return _json(
        "https://places.googleapis.com/v1/places/"
            + _place_id(place_id)
            + "?"
            + urlencode({"sessionToken": _session(session_token)}),
        "id"
    );
}

def _map(place_id: str) -> dict {
    details = _json(
        "https://places.googleapis.com/v1/places/" + _place_id(place_id), "location"
    );
    point = details["location"];
    center = str(point["latitude"]) + "," + str(point["longitude"]);
    params = urlencode(
        {
            "key": _key(),
            "size": "600x300",
            "scale": "1",
            "zoom": "15",
            "center": center,
            "markers": "color:0x7465dc|" + center
        }
    );
    with urlopen(
        "https://maps.googleapis.com/maps/api/staticmap?" + params, timeout=10
    ) as response {
        if not response.headers.get("Content-Type", "").startswith("image/") {
            raise ValueError("Google map unavailable");
        }
        # No persistent image cache; the complete Google image retains attribution.
        image = base64.b64encode(response.read(2097152)).decode();
        return {"image": "data:image/png;base64," + image};
    }
}
