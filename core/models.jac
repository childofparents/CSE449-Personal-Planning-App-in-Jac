"""One aggregate per authenticated root; Jac commits each request atomically."""

node Planner {
    has schema_version: int = 2;
    has tasks: dict = {};
    has blocks: dict = {};
    has exceptions: dict = {};
    has work_weeks: dict = {};
    has preferences: dict = {};
    has series: dict = {};
}

def _preferences() -> dict {
    return {
        "revision": 1,
        "timezone": "America/Detroit",
        "gym_locations": [
            "Hadley Rec Center",
            "North Campus Recreation Building (NCRB)"
        ],
        "work_location": "Evergreen Plymouth (2771 Plymouth Rd, Ann Arbor, MI 48105)",
        "work_default_start": "16:30",
        "work_default_end": "21:00",
        "work_possible_weekdays": [0, 1, 2, 3, 4, 5, 6],
        "gym_weekdays": [0, 1, 2, 3, 4],
        "gym_budget_minutes": 150,
        "usual_gym_arrival": "09:00",
        "usual_gym_departure": "10:45",
        "friday_gym_arrival": "10:00",
        "routes": [
            {
                "weekdays": [1, 3],
                "origin": "Hadley Rec Center",
                "destination": "AHB",
                "minutes": 10,
                "estimated": False
            },
            {
                "weekdays": [4],
                "origin": "AAS 254 discussion",
                "destination": "Hadley Rec Center",
                "minutes": 10,
                "estimated": True
            }
        ],
        "daily_availability": None,
        "travel_buffer_minutes": None,
        "work_approximate_days": 2,
        "work_publication_weekday": 4
    };
}

def _classes() -> dict {
    result = {};
    for (key, title, days, start, end, location) in [
        ("eecs449", "EECS 449 lecture", [0, 2], "13:30", "15:20", "CHRYS 133"),
        ("org201", "ORGSTUDY 201 lecture", [0, 2], "16:00", "17:20", "EHB844"),
        ("aas254", "AAS 254 lecture", [1, 3], "11:30", "12:50", "AHB"),
        ("org201-disc", "ORGSTUDY 201 discussion", [3], "16:00", "16:50", "WEIS755"),
        ("aas254-disc", "AAS 254 discussion", [4], "09:00", "09:50", "TMCG020")
    ] {
        result[key] = {
            "id": key,
            "title": title,
            "weekdays": days,
            "start_time": start,
            "end_time": end,
            "location": location,
            "first_date": "2026-08-31",
            "last_date": "2026-12-11",
            "revision": 1
        };
    }
    return result;
}
