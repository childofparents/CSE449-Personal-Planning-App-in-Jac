"""Cadence terminal app. All planner data lives in the running service."""
import argparse;
import sys;
import os;
import json;
import getpass;
import datetime as dt;
import from cli.client {
    ClientError,
    read_session,
    save_session,
    logout,
    normalize_server,
    post,
    api
}
import from cli.output { today, date_value, instant, task_text, agenda_text, safe }

glob CATEGORIES = ["academics", "gym", "social/campus", "personal", "travel"];

def parser() -> any {
    p = argparse.ArgumentParser(
        prog="jac run cli --",
        description="Cadence: quick edits and day/week previews of your shared planner."
    );
    p.add_argument(
        "--server",
        help="Planner origin (or CADENCE_SERVER); default saved server or http://127.0.0.1:8000"
    );
    p.add_argument(
        "--json",
        action="store_true",
        help="Print a machine-readable success/error envelope"
    );
    commands = p.add_subparsers(dest="command", required=True);
    login = commands.add_parser(
        "login", help="Sign in using the same account as web/mobile"
    );
    login.add_argument("username");
    login.add_argument(
        "--password-stdin",
        action="store_true",
        help="Read password from stdin instead of a hidden prompt"
    );
    commands.add_parser("logout", help="Remove this CLI's saved session");
    commands.add_parser(
        "status", help="Show the configured server/account without revealing its token"
    );
    for name in ["day", "week", "check"] {
        sub = commands.add_parser(name, help="Preview " + name + " (Detroit time)");
        sub.add_argument(
            "date", nargs="?", `default="today", help="YYYY-MM-DD; default today"
        );
    }
    tasks = commands.add_parser(
        "tasks", help="List/search tasks without changing calendar events"
    );
    tasks.add_argument("--state", choices=["open", "done", "all"], `default="open");
    tasks.add_argument("--search", `default="");
    tasks.add_argument("--category", choices=CATEGORIES);
    for name in ["add", "edit"] {
        sub = commands.add_parser(
            name, help=("Create a task" if name == "add" else "Edit a task")
        );
        sub.add_argument("title" if name == "add" else "id");
        if name == "edit" {
            sub.add_argument("--title");
            sub.add_argument("--revision", type=int);
        }
        sub.add_argument(
            "--category",
            choices=CATEGORIES,
            `default="personal" if name == "add" else None
        );
        sub.add_argument("--minutes", type=int, `default=60 if name == "add" else None);
    }
    for name in ["done", "reopen"] {
        sub = commands.add_parser(name, help="Set task completion status");
        sub.add_argument("id");
        sub.add_argument("--revision", type=int);
    }
    schedule = commands.add_parser("schedule", help="Schedule a task session");
    schedule.add_argument("id");
    schedule.add_argument(
        "--start",
        required=True,
        help="YYYY-MM-DDTHH:MM in Detroit, or offset-aware ISO timestamp"
    );
    schedule.add_argument("--end", help="Default: start plus task duration");
    schedule.add_argument("--location", `default="");
    schedule.add_argument("--origin", `default="");
    schedule.add_argument("--destination", `default="");
    event = commands.add_parser(
        "event", help="Create a calendar event, gym visit, or travel block"
    );
    event.add_argument("title");
    event.add_argument("--start", required=True);
    event.add_argument("--end", required=True);
    event.add_argument("--category", choices=CATEGORIES);
    event.add_argument("--kind", choices=["event", "gym", "travel"], `default="event");
    event.add_argument("--location", `default="");
    event.add_argument("--origin", `default="");
    event.add_argument("--destination", `default="");
    event.add_argument("--linked-to", `default="");
    event.add_argument("--estimated", action="store_true");
    move = commands.add_parser(
        "move",
        help="Move an event or one class occurrence, keeping server conflict checks"
    );
    move.add_argument("id");
    move.add_argument(
        "--on", required=True, help="A date in the event's CURRENT week (YYYY-MM-DD)"
    );
    move.add_argument("--start", required=True);
    move.add_argument("--end", required=True);
    move.add_argument("--location");
    move.add_argument("--revision", type=int);
    shift = commands.add_parser(
        "shift", help="Add a dated restaurant shift on any day, including weekends"
    );
    shift.add_argument("date");
    shift.add_argument("--start", `default="16:30", help="HH:MM");
    shift.add_argument("--end", `default="21:00", help="HH:MM");
    shift.add_argument("--end-date", help="For a shift ending on a different date");
    work = commands.add_parser(
        "work", help="Mark the selected week's shift schedule published or pending"
    );
    work.add_argument("state", choices=["published", "pending"]);
    work.add_argument("date", nargs="?", `default="today");
    work.add_argument("--revision", type=int);
    delete = commands.add_parser(
        "delete", help="Delete a task/event after explicit confirmation"
    );
    delete.add_argument("target", choices=["task", "event"]);
    delete.add_argument("id");
    delete.add_argument("--on", help="Current week date required for an event");
    delete.add_argument("--revision", type=int);
    delete.add_argument(
        "--yes",
        action="store_true",
        help="Confirm deletion (task sessions stay; event-linked travel is deleted)"
    );
    return p;
}

def choose(records: list, identifier: str) -> dict {
    exact = [
        r
        for r in records
        if r["id"] == identifier
    ];
    if len(exact) == 1 {
        return exact[0];
    }
    matches = [
        r
        for r in records
        if r["id"].startswith(identifier)
    ];
    if not identifier or len(matches) != 1 {
        raise ClientError(
            "id",
            "ID must match exactly one record. Use a full ID or an unambiguous prefix from tasks/week."
        );
    }
    return matches[0];
}

def revision(args: any, record: dict) -> int {
    return args.revision if args.revision is not None else record["revision"];
}

def execute(args: any) -> dict {
    if args.command == "logout" {
        logout();
        return {"message": "Signed out of the CLI. Other interfaces are unchanged."};
    }
    session = read_session();
    server = normalize_server(
        args.server
            or os.environ.get("CADENCE_SERVER")
            or session.get("server")
            or "http://127.0.0.1:8000"
    );
    token = os.environ.get("CADENCE_TOKEN", "");
    if not token and session.get("server") == server {
        token = session.get("token", "");
    }
    if args.command == "login" {
        password = sys.stdin.readline().rstrip("\r\n")
            if args.password_stdin
            else getpass.getpass("Password: ");
        if not password or not args.username.strip() {
            raise ValueError("Username and password are required.");
        }
        body = post(
            server,
            "/user/login",
            {
                "identity": {"type": "username", "value": args.username.strip()},
                "credential": {"type": "password", "password": password}
            }
        );
        data = body.get("data") or {};
        if not data.get("token") {
            raise ClientError("auth", "Login did not return a session token.");
        }
        save_session(
            {"server": server, "token": data["token"], "account": args.username.strip()}
        );
        return {"message": "Signed in as " + args.username.strip(), "server": server};
    }
    if args.command == "status" {
        return {
            "server": server,
            "account": session.get("account", "")
                if session.get("server") == server
                    and not os.environ.get("CADENCE_TOKEN")
                else "",
            "session_available": bool(token),
            "token_source": "environment"
                if os.environ.get("CADENCE_TOKEN")
                else "saved session" if token else "none"
        };
    }
    if args.command == "delete" {
        if not args.yes {
            raise ValueError(
                "Deletion requires --yes. Deleting a task preserves its scheduled events; deleting an event also removes linked travel. Classes are canceled for one occurrence only."
            );
        }
        if args.target == "task" {
            task = choose(
                api(server, token, "list_tasks", {"include_completed": True}), args.id
            );
            return {
                "deleted": api(
                    server,
                    token,
                    "remove_task",
                    {"task_id": task["id"], "expected_revision": revision(args, task)}
                )
            };
        }
        if not args.on {
            raise ValueError(
                "Event deletion requires --on YYYY-MM-DD in its current week."
            );
        }
        week = api(server, token, "get_week", {"day": date_value(args.on)});
        records = {};
        for day in week["days"] {
            for b in day["blocks"] {
                records[b["id"]] = b;
            }
        }
        block = choose(list(records.values()), args.id);
        if block["kind"] == "class" {
            return {
                "deleted": api(
                    server,
                    token,
                    "set_occurrence_exception",
                    {
                        "series_id": block["series_id"],
                        "occurrence_date": block["occurrence_date"],
                        "expected_revision": revision(args, block),
                        "action": "cancel"
                    }
                )
            };
        }
        return {
            "deleted": api(
                server,
                token,
                "remove_block",
                {
                    "block_id": block["id"],
                    "expected_revision": revision(args, block),
                    "include_linked_travel": True
                }
            )
        };
    }
    if args.command in ["day", "week", "check"] {
        operation = "get_day"
            if args.command == "day"
            else "check_schedule" if args.command == "check" else "get_week";
        return {
            "agenda": api(server, token, operation, {"day": date_value(args.date)})
        };
    }
    if args.command in ["tasks", "edit", "done", "reopen", "schedule"] {
        tasks = api(server, token, "list_tasks", {"include_completed": True});
        if args.command == "tasks" {
            return {
                "tasks": [
                    t
                    for t in tasks
                    if (args.state == "all" or t["completed"] == (args.state == "done"))
                        and (not args.category or t["category"] == args.category)
                        and args.search.casefold() in t["title"].casefold()
                ]
            };
        }
        task = choose(tasks, args.id);
        if args.command in ["edit", "done", "reopen"] {
            changes = {};
            if args.command == "edit" {
                if args.title is not None {
                    changes["title"] = args.title;
                }
                if args.category is not None {
                    changes["category"] = args.category;
                }
                if args.minutes is not None {
                    changes["duration_minutes"] = args.minutes;
                }
                if not changes {
                    raise ValueError(
                        "Supply --title, --category, or --minutes to edit."
                    );
                }
            } else {
                changes["completed"] = args.command == "done";
            }
            result = api(
                server,
                token,
                "update_task",
                {
                    "task_id": task["id"],
                    "expected_revision": revision(args, task),
                    "changes": changes
                }
            );
            return {"task": result};
        }
        start = instant(args.start);
        end = instant(args.end)
            if args.end
            else (
                dt.datetime.fromisoformat(start).astimezone(dt.timezone.utc)
                + dt.timedelta(minutes=task["duration_minutes"])
            ).isoformat();
        kind = task["category"] if task["category"] in ["gym", "travel"] else "session";
        return {
            "event": api(
                server,
                token,
                "create_block",
                {
                    "title": task["title"],
                    "category": task["category"],
                    "kind": kind,
                    "task_id": task["id"],
                    "start": start,
                    "end": end,
                    "location": args.location,
                    "origin": args.origin,
                    "destination": args.destination
                }
            )
        };
    }
    if args.command == "add" {
        return {
            "task": api(
                server,
                token,
                "create_task",
                {
                    "title": args.title,
                    "category": args.category,
                    "duration_minutes": args.minutes
                }
            )
        };
    }
    if args.command in ["event", "shift"] {
        if args.command == "shift" {
            day = date_value(args.date);
            end_day = date_value(args.end_date) if args.end_date else day;
            payload: dict = {
                "title": "Restaurant shift",
                "kind": "work",
                "category": "personal",
                "start": instant(day + "T" + args.start),
                "end": instant(end_day + "T" + args.end),
                "location": "Evergreen Plymouth (2771 Plymouth Rd, Ann Arbor, MI 48105)"
            };
        } else {
            payload = {
                "title": args.title,
                "start": instant(args.start),
                "end": instant(args.end),
                "kind": args.kind,
                "category": args.category
                    or (args.kind if args.kind in ["gym", "travel"] else "personal"),
                "location": args.location,
                "origin": args.origin,
                "destination": args.destination,
                "linked_to": args.linked_to,
                "estimated": args.estimated
            };
        }
        return {"event": api(server, token, "create_block", payload)};
    }
    if args.command in ["move", "work"] {
        week = api(
            server,
            token,
            "get_week",
            {"day": date_value(args.on if args.command == "move" else args.date)}
        );
        if args.command == "work" {
            record = week["work_weeks"][0];
            return {
                "work_week": api(
                    server,
                    token,
                    "set_work_week",
                    {
                        "week_start": record["week_start"],
                        "expected_revision": revision(args, record),
                        "published": args.state == "published"
                    }
                )
            };
        }
        unique = {};
        for day in week["days"] {
            for b in day["blocks"] {
                unique[b["id"]] = b;
            }
        }
        block = choose(list(unique.values()), args.id);
        payload = {
            "expected_revision": revision(args, block),
            "start": instant(args.start),
            "end": instant(args.end)
        };
        if args.location is not None {
            payload["location"] = args.location;
        }
        operation = "move_block";
        if block["kind"] == "class" {
            operation = "set_occurrence_exception";
            payload.update(
                {
                    "series_id": block["series_id"],
                    "occurrence_date": block["occurrence_date"],
                    "action": "move"
                }
            );
        } else {
            payload["block_id"] = block["id"];
        }
        return {"event": api(server, token, operation, payload)};
    }
    raise ValueError("Unknown command.");
}

def main(argv: list) -> int {
    args = parser().parse_args(argv);
    try {
        data = execute(args);
        if args.json {
            print(
                json.dumps({"ok": True, "data": data, "error": None}, ensure_ascii=True)
            );
        } elif "agenda" in data {
            print(agenda_text(data["agenda"]));
        } elif "tasks" in data {
            print(task_text(data["tasks"]));
        } elif "task" in data {
            print("Saved task\n" + task_text([data["task"]]));
        } else {
            print(
                safe(data["message"])
                    if "message" in data
                    else json.dumps(data, indent=2, ensure_ascii=True)
            );
        }
        return 0;
    } except (ClientError, ValueError, OSError) as e {
        error = {
            "code": getattr(e, "code", "validation"),
            "message": str(e),
            "details": getattr(e, "details", None)
        };
        if args.json {
            print(
                json.dumps(
                    {"ok": False, "data": None, "error": error}, ensure_ascii=True
                )
            );
        } else {
            print("Cadence: " + safe(str(e)), file=sys.stderr);
            if error["details"] is not None {
                print(
                    json.dumps(error["details"], indent=2, ensure_ascii=True),
                    file=sys.stderr
                );
            }
        }
        return 1;
    }
}

with entry {
    sys.exit(main(sys.argv[1:]));
}
