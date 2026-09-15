"""Google Places (New) suggestions and Google Maps Embed previews.
The browser key is injected by an ignored jac.local.toml; ordinary locations work without it.
"""
import from "react" { useRef, useEffect }
import from "@googlemaps/js-api-loader" { setOptions, importLibrary }

glob initialized: bool = False;

def:pub mapsKey() -> str {
    return str((globalThis as any).GOOGLE_MAPS_API_KEY or "");
}

async def placesLibrary() -> any {
    if not initialized {
        setOptions({"key": mapsKey(), "v": "weekly"});
        initialized = True;
    }
    return await importLibrary("places");
}

def:pub MapThumbnail(location: str, placeId: str = "") -> JsxElement {
    key = mapsKey();
    query = "place_id:" + placeId if placeId else location;
    <aside className="map-preview" aria-label="Event location map">
        {<iframe
            title={"Map of " + location}
            loading="lazy"
            referrerPolicy="no-referrer-when-downgrade"
            src={"https://www.google.com/maps/embed/v1/place?key="
                + encodeURIComponent(key)
                + "&q="
                + encodeURIComponent(query)}
        />
            if key and query
            else <div className="map-unavailable">
                <strong>{location or "Choose a location"}</strong>
                <p>
                    {"Map preview needs Google Maps setup. You can still save this location."
                        if location
                        else "Select a matched place to see its map here."}
                </p>
            </div>}{<a
            target="_blank"
            rel="noopener noreferrer"
            href={"https://www.google.com/maps/search/?api=1&query="
                + encodeURIComponent(location)
                + ("&query_place_id=" + encodeURIComponent(placeId) if placeId else "")}
        >
            Open in Google Maps ↗
        </a>
            if location
            else None}
    </aside>
}

def:pub LocationPicker(value: str, placeId: str, onChange: any) -> JsxElement {
    has results: any = [],
        searching: bool = False,
        failure: str = "",
        active: int = -1;
    timer = useRef(None);
    sequence = useRef(0);
    session = useRef(None);
    change = useRef(onChange);
    change.current = onChange;
    useEffect(
        lambda { return lambda {
            clearTimeout(timer.current);
            sequence.current += 1;
        }; },
        []
    );
    async def search(text: str, version: int) -> None {
        searching = True;
        try {
            library = await placesLibrary();
            if version != sequence.current {
                return;
            }
            if not session.current {
                session.current = new(library.AutocompleteSessionToken);
            }
            response = await library.AutocompleteSuggestion.fetchAutocompleteSuggestions(
                {
                    "input": text,
                    "sessionToken": session.current,
                    "locationBias": {
                        "center": {"lat": 42.2808, "lng": -83.7430},
                        "radius": 15000
                    },
                    "region": "us"
                }
            );
            if version == sequence.current {
                results = response.suggestions.filter(
                    lambda (s: any) { return bool(s.placePrediction); }
                );
                if results.length == 0 {
                    failure = "No matches. Keep typing or save the location as text.";
                }
            }
        } except Exception {
            if version == sequence.current {
                failure = "Google location search is unavailable. You can still enter an address manually.";
            }
        } finally {
            if version == sequence.current {
                searching = False;
            }
        }
    }
    def typed(text: str) -> None {
        change.current.call(None, text, "");
        sequence.current += 1;
        clearTimeout(timer.current);
        results = [];
        failure = "";
        active = -1;
        searching = False;
        if mapsKey() and len(text.strip()) >= 2 {
            version = sequence.current;
            timer.current = setTimeout(lambda { search(text, version); }, 300);
        }
    }
    async def choose(suggestion: any) -> None {
        sequence.current += 1;
        version = sequence.current;
        clearTimeout(timer.current);
        searching = True;
        failure = "";
        try {
            prediction = suggestion.placePrediction;
            place = prediction.toPlace();
            await place.fetchFields({"fields": ["id"]});
            if version != sequence.current {
                return;
            }
            change.current.call(None, prediction.text.toString(), place.id);
            results = [];
            active = -1;
        } except Exception {
            failure = "Could not select that place. Try again or keep the typed address.";
        } finally {
            session.current = None;
            if version == sequence.current {
                searching = False;
            }
        }
    }
    <div className="location-picker">
        <label>
            Location
            <input
                value={value}
                placeholder="Search a place or address"
                autoComplete="off"
                role="combobox"
                aria-autocomplete="list"
                aria-expanded={results.length > 0}
                aria-controls="place-matches"
                aria-activedescendant={"place-match-" + str(active)
                    if active >= 0
                    else ""}
                onInput={lambda (e: any) { typed(e.target.value); }}
                onKeyDown={lambda (e: any) { if e.key == "ArrowDown"
                    and results.length {
                    e.preventDefault();
                    active = (active + 1) % results.length;
                } elif e.key == "ArrowUp" and results.length {
                    e.preventDefault();
                    active = (active + results.length - 1) % results.length;
                } elif e.key == "Enter" and active >= 0 {
                    e.preventDefault();
                    choose(results[active]);
                } elif e.key == "Escape" and results.length {
                    e.stopPropagation();
                    results = [];
                    active = -1;
                }   }}
            />
        </label>
        {<div
            id="place-matches"
            className="place-matches"
            role="listbox"
            aria-label="Matching Google locations"
        >
            {results.map(
                lambda (s: any, i: int) { return
                    <button
                        type="button"
                        key={s.placePrediction.placeId}
                        id={"place-match-" + str(i)}
                        role="option"
                        aria-selected={active == i}
                        onClick={lambda { choose(s); }}
                    >
                        {s.placePrediction.text.toString()}
                    </button>; }
            )}
            <div className="google-attribution" translate="no">Google Maps</div>
        </div>
            if results.length
            else None}
        {<p role="status" className="form-hint">Searching locations…</p>
            if searching
            else None}
        {<p role="status" className="form-hint">{failure}</p> if failure else None}
        {<p className="form-hint">
            Google suggestions are not configured. Enter a location manually.
        </p>
            if not mapsKey()
            else None}
        {<span className="place-selected">✓ Google place selected</span>
            if placeId
            else None}
    </div>
}
