"""Cadence: a personal weekly planner. All saved operations use the authenticated planner API."""
import "./global.css";
import from .locations { LocationPicker, MapThumbnail }
import from "lucide-react" {
    CalendarDays,
    Inbox,
    CheckCheck,
    Plus,
    Search,
    ChevronLeft,
    ChevronRight,
    ArrowUpRight,
    X,
    RefreshCw,
    MapPin,
    Clock3,
    Dumbbell,
    GraduationCap,
    BriefcaseBusiness,
    SlidersHorizontal,
    LogOut,
    ArrowRight,
    CircleHelp,
    Sun,
    Menu,
    Check,
    Coffee
}
import from .support {
    today,
    monday,
    shift,
    label,
    clock,
    stamp,
    minute,
    tone,
    uid,
    api,
    request,
    previewWeek,
    previewTasks,
    eventStyle,
    calendarBounds,
    trapFocus
}

def:pub app() -> JsxElement {
    has selected: str = today(),
        week: any = previewWeek(today()),
        tasks: any = previewTasks(),
        token: str = "",
        username: str = "",
        password: str = "",
        account: str = "",
        mode: str = "calendar",
        filter: str = "all",
        query: str = "",
        weekends: bool = True,
        busy: bool = False,
        error: str = "",
        notice: str = "",
        modal: str = "",
        register: bool = False,
        title: str = "",
        category: str = "academics",
        duration: str = "60",
        day: str = today(),
        startTime: str = "17:30",
        endTime: str = "18:30",
        location: str = "",
        placeId: str = "",
        kind: str = "event",
        taskId: str = "",
        detail: any = None,
        origin: str = "",
        destination: str = "",
        navOpen: bool = False;

    async can with entry {
        document.title = "Cadence · Your weekly planner";
        saved = sessionStorage.getItem("cadence-token");
        if saved {
            week = {
                ** week,
                "days": week.days.map(lambda (d: any) { return {** d, "blocks": []}; })
            };
            tasks = [];
            token = saved;
            account = sessionStorage.getItem("cadence-account") or "My account";
            await load(selected, saved);
        }
    }
    async def load(date: str, auth: str) -> None {
        busy = True;
        error = "";
        try {
            w = await api("get_week", {"day": date}, auth);
            t = await api("list_tasks", {"include_completed": True}, auth);
            week = w;
            tasks = t;
        } except Exception as e {
            error = str(e);
        } finally {
            busy = False;
        }
    }
    async def navigate(date: str) -> None {
        selected = date;
        if token {
            await load(date, token);
        } else {
            week = previewWeek(date);
        }
    }
    def openForm(which: str) -> None {
        error = "";
        notice = "";
        title = "";
        category = "academics";
        kind = "event";
        location = "";
        placeId = "";
        taskId = "";
        detail = None;
        origin = "";
        destination = "";
        day = selected;
        startTime = "17:30";
        endTime = "18:30";
        modal = which;
    }
    def inspect(block: any) -> None {
        detail = block;
        location = block.location or "";
        placeId = block.place_id or "";
        day = label(block.start, "yyyy-MM-dd");
        startTime = label(block.start, "HH:mm");
        endTime = label(block.end, "HH:mm");
        error = "";
        modal = "detail";
    }
    async def signIn(e: FormEvent) -> None {
        e.preventDefault();
        busy = True;
        error = "";
        try {
            payload: any = {
                "identity": {"type": "username", "value": username},
                "credential": {"type": "password", "password": password}
            };
            if register {
                payload = {
                    "identities": [{"type": "username", "value": username}],
                    "credential": {"type": "password", "password": password}
                };
            }
            result = await request(
                "/user/register" if register else "/user/login", payload
            );
            auth = result.data.token;
            if not auth {
                raise Exception("Sign-in did not return a session.");
            }
            sessionStorage.setItem("cadence-token", auth);
            sessionStorage.setItem("cadence-account", username);
            week = {
                ** week,
                "days": week.days.map(lambda (d: any) { return {** d, "blocks": []}; })
            };
            tasks = [];
            token = auth;
            account = username;
            password = "";
            modal = "";
            await load(selected, auth);
        } except Exception as e {
            error = str(e);
        } finally {
            busy = False;
        }
    }
    def signOut() -> None {
        sessionStorage.removeItem("cadence-token");
        sessionStorage.removeItem("cadence-account");
        token = "";
        account = "";
        tasks = previewTasks();
        week = previewWeek(selected);
        error = "";
        notice = "Signed out. You’re viewing the preview.";
    }
    async def completeTask(task: any) -> None {
        error = "";
        busy = True;
        try {
            if token {
                await api(
                    "update_task",
                    {
                        "task_id": task.id,
                        "expected_revision": task.revision,
                        "changes": {"completed": not task.completed}
                    },
                    token
                );
                await load(selected, token);
            } else {
                tasks = tasks.map(
                    lambda (t: any) { return {** t, "completed": not t.completed}
                        if t.id == task.id
                        else t; }
                );
            }
            notice = "Task updated"
                if token
                else "Preview task updated — not saved to an account";
        } except Exception as e {
            error = str(e);
        } finally {
            busy = False;
        }
    }
    async def save(e: FormEvent) -> None {
        e.preventDefault();
        error = "";
        busy = True;
        try {
            if not title.strip() {
                raise Exception("Give this a title first.");
            }
            if modal == "task" or modal == "editTask" {
                payload = {
                    "title": title.strip(),
                    "category": category,
                    "duration_minutes": int(duration)
                };
                if modal == "editTask" {
                    if token {
                        await api(
                            "update_task",
                            {
                                "task_id": detail.id,
                                "expected_revision": detail.revision,
                                "changes": payload
                            },
                            token
                        );
                    } else {
                        tasks = tasks.map(
                            lambda (t: any) { return {** t, ** payload}
                                if t.id == detail.id
                                else t; }
                        );
                    }
                } elif token {
                    await api("create_task", payload, token);
                } else {
                    tasks = [
                        *tasks,
                        {
                            ** payload,
                            "id": uid(),
                            "completed": False,
                            "revision": 1,
                            "block_ids": []
                        }
                    ];
                }
            } else {
                start = stamp(day, startTime);
                end = stamp(day, endTime);
                if not start or not end or end <= start {
                    raise Exception("End time must be after start time.");
                }
                block = {
                    "title": title.strip(),
                    "start": start,
                    "end": end,
                    "category": category,
                    "kind": kind,
                    "location": location,
                    "place_id": placeId,
                    "task_id": taskId,
                    "origin": origin,
                    "destination": destination
                };
                if token {
                    await api("create_block", block, token);
                } else {
                    base = week
                        if monday(day) == monday(selected)
                        else previewWeek(day);
                    occupied = base.days.flatMap(lambda (d: any) { return d.blocks; });
                    conflict = occupied.find(
                        lambda (b: any) { return stamp(
                            label(b.start, "yyyy-MM-dd"), label(b.start, "HH:mm")
                        )
                            < end
                            and start
                                < stamp(
                                    label(b.end, "yyyy-MM-dd"), label(b.end, "HH:mm")
                                ); }
                    );
                    if conflict {
                        raise Exception(
                            "Overlaps " + conflict.title + ". Choose another time."
                        );
                    }
                    week = {
                        ** base,
                        "days": base.days.map(
                            lambda (d: any) { return {
                                ** d,
                                "blocks": [
                                    *d.blocks,
                                    {** block, "id": uid(), "revision": 1}
                                ]
                            }
                                if d.date == day
                                else d; }
                        )
                    };
                    selected = day;
                }
            }
            savedDate = day if modal == "block" else selected;
            modal = "";
            notice = "Saved to your planner"
                if token
                else "Added to this preview only. Sign in to save your plan.";
            if token {
                await navigate(savedDate);
            }
        } except Exception as e {
            error = str(e);
        } finally {
            busy = False;
        }
    }
    async def move(e: FormEvent) -> None {
        e.preventDefault();
        error = "";
        busy = True;
        try {
            if not token {
                raise Exception(
                    "Sign in to move saved commitments. Preview blocks are examples."
                );
            }
            payload: any = {
                "block_id": detail.id,
                "expected_revision": detail.revision,
                "start": stamp(day, startTime),
                "end": stamp(day, endTime),
                "location": location,
                "place_id": placeId
            };
            operation = "move_block";
            if detail.kind == "class" {
                operation = "set_occurrence_exception";
                payload = {
                    "series_id": detail.series_id,
                    "occurrence_date": detail.occurrence_date,
                    "expected_revision": detail.revision,
                    "action": "move",
                    "start": stamp(day, startTime),
                    "end": stamp(day, endTime),
                    "location": location,
                    "place_id": placeId
                };
            }
            await api(operation, payload, token);
            modal = "";
            notice = "Time block moved";
            await navigate(day);
        } except Exception as e {
            error = str(e);
        } finally {
            busy = False;
        }
    }
    async def publish() -> None {
        if not token {
            modal = "auth";
            return;
        }
        busy = True;
        error = "";
        try {
            w = week.work_weeks[0];
            await api(
                "set_work_week",
                {
                    "week_start": w.week_start,
                    "expected_revision": w.revision,
                    "published": not w.published
                },
                token
            );
            await load(selected, token);
            notice = "Work schedule status updated";
        } except Exception as e {
            error = str(e);
        } finally {
            busy = False;
        }
    }

    navigation: any = [
        [CalendarDays, "calendar", "My week"],
        [Inbox, "tasks", "My tasks"],
        [CheckCheck, "completed", "Completed"]
    ];
    categories: any = [
        ["academics", "Academics"],
        ["gym", "Gym & wellbeing"],
        ["social/campus", "Social & campus"],
        ["personal", "Personal & work"],
        ["travel", "Travel"]
    ];
    visibleDays = week.days.filter(
        lambda (d: any, i: int) { return weekends or i < 5; }
    );
    allBlocks = week.days.flatMap(lambda (d: any) { return d.blocks; });
    limits = calendarBounds(allBlocks);
    hours: any = list(range(limits.start, limits.end));
    shownTasks = tasks.filter(
        lambda (t: any) { return (filter == "all" or t.category == filter)
            and t.title.toLowerCase().includes(query.lower())
            and (t.completed if mode == "completed" else not t.completed); }
    );
    completedCount = tasks.filter(lambda (t: any) { return t.completed; }).length;
    gymDays = week.days.filter(
        lambda (d: any) { return d.blocks.some(
            lambda (b: any) { return b.kind == "gym"; }
        ); }
    ).length;
    classCount = allBlocks.filter(lambda (b: any) { return b.kind == "class"; }).length;
    first = monday(selected);
    work = week.work_weeks[0];

    <div className="shell">
        <aside className={"sidebar " + ("open" if navOpen else "")}>
            <a
                href="#"
                className="brand"
                onClick={lambda (e: any) {
                    e.preventDefault();
                    mode = "calendar";
                }}
            >
                <span className="brand-mark">c</span>
                cadence
                <span className="brand-dot">.</span>
            </a>
            <div className="workspace">
                <span className="avatar">BL</span>
                <div>
                    <strong>Personal space</strong>
                    <small>Fall 2026 · Ann Arbor</small>
                </div>
            </div>
            <div className="section-label">WORKSPACE</div>
            <nav aria-label="Main navigation">
                {navigation.map(
                    lambda (n: any) {
                        icon = n[0];
                        return
                            <button
                                key={n[1]}
                                className={"nav-item "
                                    + ("active" if mode == n[1] else "")}
                                onClick={lambda {
                                    mode = n[1];
                                    navOpen = False;
                                }}
                            >
                                <@icon size={18}/>
                                {n[2]}
                                {<span className="nav-count">
                                    {tasks.length - completedCount}
                                </span>
                                    if n[1] == "tasks"
                                    else None}
                            </button>;
                    }
                )}
            </nav>
            <div className="section-label category-heading">
                YOUR CALENDARS
                <button
                    aria-label="Show all categories"
                    onClick={lambda { filter = "all"; }}
                >
                    <SlidersHorizontal size={14}/>
                </button>
            </div>
            {categories.map(
                lambda (c: any) { return
                    <button
                        key={c[0]}
                        className={"category-row "
                            + ("muted" if filter != "all" and filter != c[0] else "")}
                        aria-pressed={filter == c[0]}
                        onClick={lambda { filter = "all" if filter == c[0] else c[0]; }}
                    >
                        <span className={"color-dot " + tone(c[0])}></span>
                        {c[1]}
                        <Check size={13}/>
                    </button>; }
            )}
            <div className="sidebar-note">
                <span className="tiny-stars">✳</span>
                <strong>Make room for life.</strong>
                <p>
                    A little structure.
                    <br/>
                    A lot of possibility.
                </p>
                <span>YOUR SEMESTER, IN BALANCE</span>
            </div>
            <div className="sidebar-bottom">
                <span className="avatar small">
                    {account[:2].upper() if token else "BL"}
                </span>
                <div>
                    <strong>{account if token else "Beini’s planner"}</strong>
                    <small>{"Connected account" if token else "Design preview"}</small>
                </div>
                <button
                    aria-label={"Sign out" if token else "Sign in"}
                    onClick={lambda { signOut() if token else openForm("auth"); }}
                >
                    <LogOut size={16}/>
                </button>
            </div>
        </aside>
        <main className="main">
            <header className="topbar">
                <div className="breadcrumb">
                    <button
                        className="mobile-menu"
                        aria-label="Toggle navigation"
                        onClick={lambda { navOpen = not navOpen; }}
                    >
                        <Menu size={20}/>
                    </button>
                    <span>Workspace</span>
                    <ChevronRight size={13}/>
                    <strong>
                        {"My week"
                            if mode == "calendar"
                            else "Completed" if mode == "completed" else "My tasks"}
                    </strong>
                </div>
                <div className="top-actions">
                    <span className="semester">FALL SEMESTER 2026</span>
                    <button
                        className="icon-button"
                        aria-label="Refresh planner"
                        disabled={busy}
                        onClick={lambda { navigate(selected); }}
                    >
                        <RefreshCw size={16}/>
                    </button>
                    <span className={"connection " + ("live" if token else "")}>
                        {"Connected" if token else "Preview"}
                    </span>
                </div>
            </header>
            <div className="page-content">
                <div className="page-heading">
                    <div>
                        <div className="eyebrow">
                            A LITTLE INTENTION GOES A LONG WAY
                        </div>
                        <h1>
                            {"Your week, in balance."
                                if mode == "calendar"
                                else "A clear mind starts here."
                                    if mode == "tasks"
                                    else "Look at you go."}
                        </h1>
                        <p>Space for learning, moving, and everything in between.</p>
                    </div>
                    <button className="primary" onClick={lambda { openForm("task"); }}>
                        <Plus size={17}/>
                        Create task
                    </button>
                </div>
                {<div className="preview-bar">
                    <span>
                        <span className="preview-dot"></span>
                        Preview workspace{" "}
                        <span className="preview-copy">
                            · Your classes, suggested gym blocks, and sample tasks. Changes aren’t saved.
                        </span>
                    </span>
                    <button onClick={lambda { openForm("auth"); }}>
                        Sign in to your planner{" "}
                        <ArrowRight size={14}/>
                    </button>
                </div>
                    if not token
                    else None}
                {<div className="message error" role="alert">
                    {error}
                    <button aria-label="Dismiss error" onClick={lambda { error = ""; }}>
                        <X size={14}/>
                    </button>
                </div>
                    if error and not modal
                    else None}
                {<div className="message" role="status">
                    {notice}
                    <button
                        aria-label="Dismiss notification"
                        onClick={lambda { notice = ""; }}
                    >
                        <X size={14}/>
                    </button>
                </div>
                    if notice
                    else None}
                <div className="stats">
                    <div className="stat">
                        <span className="stat-icon violet">
                            <GraduationCap size={20}/>
                        </span>
                        <div>
                            <small>Class meetings</small>
                            <strong>
                                {classCount}
                                <span>this week</span>
                            </strong>
                        </div>
                        <span className="stat-mini">3 courses</span>
                    </div>
                    <div className="stat">
                        <span className="stat-icon green">
                            <Dumbbell size={20}/>
                        </span>
                        <div>
                            <small>Gym days planned</small>
                            <strong>
                                {gymDays}
                                <span>/ 5 weekdays</span>
                            </strong>
                        </div>
                        <div className="gym-bars">
                            {week.days.slice(0, 5).map(
                                lambda (d: any) { return
                                    <i
                                        key={d.date}
                                        className={"filled"
                                            if d.blocks.some(
                                                lambda (b: any) { return b.kind
                                                    == "gym"; }
                                            )
                                            else ""}
                                    ></i>; }
                            )}
                        </div>
                    </div>
                    <div className="stat">
                        <span className="stat-icon orange">
                            <CheckCheck size={20}/>
                        </span>
                        <div>
                            <small>Tasks completed</small>
                            <strong>
                                {completedCount}
                                <span>/ {tasks.length} total</span>
                            </strong>
                        </div>
                        <span className="stat-mini">One step at a time</span>
                    </div>
                </div>
                <div
                    className={"dashboard "
                        + ("task-view" if mode != "calendar" else "")}
                >
                    <section className="calendar-card" aria-label="Weekly calendar">
                        <div className="calendar-toolbar">
                            <div>
                                <h2>{label(first, "MMMM yyyy")}</h2>
                                <span>
                                    {label(first, "MMM d")} – {label(
                                        shift(first, 6), "MMM d"
                                    )}
                                </span>
                            </div>
                            <div className="calendar-controls">
                                <button
                                    className="plain-button"
                                    disabled={busy}
                                    onClick={lambda { navigate(today()); }}
                                >
                                    Today
                                </button>
                                <button
                                    className="icon-button"
                                    aria-label="Previous week"
                                    disabled={busy}
                                    onClick={lambda { navigate(shift(first, -7)); }}
                                >
                                    <ChevronLeft size={16}/>
                                </button>
                                <button
                                    className="icon-button"
                                    aria-label="Next week"
                                    disabled={busy}
                                    onClick={lambda { navigate(shift(first, 7)); }}
                                >
                                    <ChevronRight size={16}/>
                                </button>
                                <button
                                    className="plain-button view-toggle"
                                    aria-pressed={weekends}
                                    onClick={lambda { weekends = not weekends; }}
                                >
                                    {"7 days" if weekends else "Workweek"}
                                    <CalendarDays size={14}/>
                                </button>
                                <button
                                    className="primary create-event"
                                    type="button"
                                    onClick={lambda { openForm("block"); }}
                                >
                                    <Plus size={17}/>
                                    Create event
                                </button>
                            </div>
                        </div>
                        <div className="calendar-scroll">
                            <div
                                className="calendar-inner"
                                style={{"minWidth": "850px" if weekends else "600px"}}
                            >
                                <div
                                    className="day-headings"
                                    style={{
                                        "gridTemplateColumns": "3rem repeat("
                                            + str(visibleDays.length)
                                            + ", 1fr)"
                                    }}
                                >
                                    <span className="timezone">ET</span>
                                    {visibleDays.map(
                                        lambda (d: any) { return
                                            <button
                                                key={d.date}
                                                className={"day-heading "
                                                    + (
                                                        "is-today"
                                                            if d.date == today()
                                                            else ""
                                                    )}
                                                onClick={lambda {
                                                    day = d.date;
                                                    selected = d.date;
                                                }}
                                            >
                                                <span>{label(d.date, "ccc")}</span>
                                                <strong>{label(d.date, "d")}</strong>
                                            </button>; }
                                    )}
                                </div>
                                <div
                                    className="time-grid"
                                    style={{
                                        "gridTemplateColumns": "3rem repeat("
                                            + str(visibleDays.length)
                                            + ", 1fr)",
                                        "height": str((limits.end - limits.start) * 4)
                                            + "rem"
                                    }}
                                >
                                    <div className="time-labels">
                                        {hours.map(
                                            lambda (h: int) { return
                                                <span
                                                    key={h}
                                                    style={{
                                                        "top": str(
                                                            (h - limits.start) * 4
                                                        )
                                                            + "rem"
                                                    }}
                                                >
                                                    {str(h if h <= 12 else h - 12)}
                                                    <small>
                                                        {"AM" if h < 12 else "PM"}
                                                    </small>
                                                </span>; }
                                        )}
                                    </div>
                                    {visibleDays.map(
                                        lambda (d: any) { return
                                            <div
                                                key={d.date}
                                                className={"day-column "
                                                    + (
                                                        "today-column"
                                                            if d.date == today()
                                                            else ""
                                                    )}
                                            >
                                                {hours.map(
                                                    lambda (h: int) { return
                                                        <button
                                                            key={h}
                                                            className="hour-slot"
                                                            aria-label={"Add block on "
                                                                + d.date
                                                                + " at "
                                                                + str(h)
                                                                + ":00"}
                                                            onClick={lambda {
                                                                openForm("block");
                                                                day = d.date;
                                                                startTime = str(
                                                                    h
                                                                ).zfill(
                                                                    2
                                                                )
                                                                    + ":00";
                                                                endTime = str(
                                                                    min(h + 1, 23)
                                                                ).zfill(
                                                                    2
                                                                )
                                                                    + (
                                                                        ":59"
                                                                            if h == 23
                                                                            else ":00"
                                                                    );
                                                            }}
                                                        ></button>; }
                                                )}{d.blocks.filter(
                                                    lambda (b: any) { return (
                                                        filter == "all"
                                                        or b.category == filter
                                                    ); }
                                                ).map(
                                                    lambda (b: any) { return
                                                        <button
                                                            key={b.id}
                                                            className={"event "
                                                                + tone(b.category)
                                                                + (
                                                                    " compact"
                                                                        if b.kind
                                                                            == "travel"
                                                                        else ""
                                                                )}
                                                            style={eventStyle(
                                                                b, d.date, limits.start
                                                            )}
                                                            onClick={lambda { inspect(
                                                                b
                                                            ); }}
                                                            title={b.title
                                                                + " · "
                                                                + clock(b.start)
                                                                + "–"
                                                                + clock(b.end)}
                                                        >
                                                            <span
                                                                className="event-time"
                                                            >
                                                                {clock(b.start)} – {clock(
                                                                    b.end
                                                                )}
                                                            </span>
                                                            <strong>{b.title}</strong>
                                                            <span
                                                                className="event-location"
                                                            >
                                                                {b.location}
                                                            </span>
                                                        </button>; }
                                                )}
                                            </div>; }
                                    )}
                                </div>
                            </div>
                        </div>
                        <div className="calendar-footer">
                            <span>
                                <span className="color-dot academics"></span>
                                Classes end 10 minutes early
                            </span>
                            <span>America/Detroit</span>
                        </div>
                    </section>
                    <aside className="right-panel">
                        <section className="task-card">
                            <div className="card-heading">
                                <h2>
                                    {"Completed"
                                        if mode == "completed"
                                        else "Task inbox"}
                                    <span>{shownTasks.length}</span>
                                </h2>
                                <button
                                    aria-label="Add task"
                                    onClick={lambda { openForm("task"); }}
                                >
                                    <Plus size={18}/>
                                </button>
                            </div>
                            <p className="card-subtitle">
                                {"A little progress, every day."
                                    if mode == "completed"
                                    else "Capture it. Make time for it."}
                            </p>
                            <label className="search">
                                <Search size={15}/>
                                <input
                                    aria-label="Search tasks"
                                    placeholder="Search your tasks..."
                                    value={query}
                                    onChange={lambda (e: ChangeEvent) { query = e.target.value; }}
                                />
                            </label>
                            <div className="task-list">
                                {shownTasks.map(
                                    lambda (t: any) { return
                                        <div className="task-row" key={t.id}>
                                            <button
                                                className={"task-check "
                                                    + (
                                                        "checked" if t.completed else ""
                                                    )}
                                                aria-label={"Mark "
                                                    + t.title
                                                    + (
                                                        " incomplete"
                                                            if t.completed
                                                            else " complete"
                                                    )}
                                                disabled={busy}
                                                onClick={lambda { completeTask(t); }}
                                            >
                                                {<Check size={12}/>
                                                    if t.completed
                                                    else None}
                                            </button>
                                            <div>
                                                <button
                                                    className="task-title"
                                                    aria-label={"Edit " + t.title}
                                                    onClick={lambda {
                                                        detail = t;
                                                        title = t.title;
                                                        category = t.category;
                                                        duration = str(
                                                            t.duration_minutes
                                                        );
                                                        error = "";
                                                        modal = "editTask";
                                                    }}
                                                >
                                                    <strong
                                                        className={"done"
                                                            if t.completed
                                                            else ""}
                                                    >
                                                        {t.title}
                                                    </strong>
                                                </button>
                                                <div className="task-meta">
                                                    <span
                                                        className={"tag "
                                                            + tone(t.category)}
                                                    >
                                                        {t.category}
                                                    </span>
                                                    <span>
                                                        <Clock3 size={11}/>
                                                        {t.duration_minutes}
                                                        m
                                                    </span>
                                                </div>
                                                <button
                                                    className="schedule-link"
                                                    onClick={lambda {
                                                        openForm("block");
                                                        title = t.title;
                                                        category = t.category;
                                                        kind = "gym"
                                                            if t.category == "gym"
                                                            else "travel"
                                                                if t.category
                                                                    == "travel"
                                                                else "session";
                                                        taskId = t.id;
                                                    }}
                                                >
                                                    {"Schedule a session"}
                                                    <ArrowUpRight size={12}/>
                                                </button>
                                            </div>
                                        </div>; }
                                )}{<div className="empty-state">
                                    <Inbox size={27}/>
                                    <strong>
                                        {"Nothing here yet"
                                            if not query
                                            else "No matching tasks"}
                                    </strong>
                                    <p>
                                        {"Add something you want to make time for."
                                            if not query
                                            else "Try another search or calendar filter."}
                                    </p>
                                </div>
                                    if shownTasks.length == 0
                                    else None}
                            </div>
                            <button
                                className="new-task"
                                onClick={lambda { openForm("task"); }}
                            >
                                <Plus size={15}/>
                                Add a task
                            </button>
                        </section>
                        <section className="work-card">
                            <div className="work-icon">
                                <BriefcaseBusiness size={18}/>
                                <span className="status-pill">
                                    {"Published"
                                        if work.published
                                        else "Awaiting schedule"}
                                </span>
                            </div>
                            <h3>Restaurant shifts</h3>
                            <p>
                                {"Your schedule is published. Add the actual shifts to this week."
                                    if work.published
                                    else "Schedule for "
                                        + label(first, "MMM d")
                                        + " is pending. Expected Friday, "
                                        + label(work.publication_date, "MMM d")
                                        + "."}
                            </p>
                            <div className="work-facts">
                                <span>~2 shifts / week</span>
                                <span>Published Fridays</span>
                            </div>
                            <button
                                onClick={lambda {
                                    openForm("block");
                                    kind = "work";
                                    category = "personal";
                                    title = "Restaurant shift";
                                    location = "Evergreen Plymouth (2771 Plymouth Rd, Ann Arbor, MI 48105)";
                                    startTime = "16:30";
                                    endTime = "21:00";
                                    weekends = True;
                                }}
                            >
                                Add a shift
                                <ArrowUpRight size={14}/>
                            </button>
                            <button
                                className="publication"
                                disabled={busy}
                                onClick={publish}
                            >
                                {"Mark as pending"
                                    if work.published
                                    else "Mark schedule published"}
                            </button>
                        </section>
                        <div className="quiet-note">
                            <Coffee size={19}/>
                            <p>
                                Free time is part of the plan.
                                <br/>
                                <strong>You don’t have to fill every gap.</strong>
                            </p>
                        </div>
                    </aside>
                </div>
            </div>
        </main>
        {<div
            className="modal-backdrop"
            onClick={lambda (e: any) { if e.target == e.currentTarget and not busy {
                modal = "";
            }}}
        >
            <section
                className={"modal event-modal" if modal == "detail" else "modal"}
                role="dialog"
                aria-modal="true"
                aria-labelledby="modal-title"
                onKeyDown={lambda (e: any) { if e.key == "Escape" and not busy {
                    modal = "";
                } else {
                    trapFocus(e);
                } }}
            >
                <button
                    className="modal-close"
                    aria-label="Close dialog"
                    disabled={busy}
                    onClick={lambda { modal = ""; }}
                >
                    <X size={20}/>
                </button>
                <span className="modal-eyebrow">YOUR PERSONAL SPACE</span>
                <h2 id="modal-title">
                    {"Create your account"
                        if modal == "auth" and register
                        else "Welcome back."
                            if modal == "auth"
                            else "Edit task"
                                if modal == "editTask"
                                else "Capture a task"
                                    if modal == "task"
                                    else detail.title
                                        if modal == "detail"
                                        else "Make time for it"}
                </h2>
                {<p className="modal-description">
                    Your saved classes, tasks, and time blocks, together.
                </p>
                    if modal == "auth"
                    else None}
                {<div className="message error" role="alert">{error}</div>
                    if error
                    else None}
                {<form onSubmit={signIn}>
                    <label>
                        Username
                        <input
                            autoFocus={True}
                            required={True}
                            autoComplete="username"
                            value={username}
                            onChange={lambda (e: ChangeEvent) { username = e.target.value; }}
                        />
                    </label>
                    <label>
                        Password
                        <input
                            required={True}
                            type="password"
                            autoComplete={"new-password"
                                if register
                                else "current-password"}
                            value={password}
                            onChange={lambda (e: ChangeEvent) { password = e.target.value; }}
                        />
                    </label>
                    <button className="primary full" disabled={busy}>
                        {"Connecting…"
                            if busy
                            else "Create account" if register else "Sign in"}
                        <ArrowRight size={15}/>
                    </button>
                    <button
                        type="button"
                        className="auth-switch"
                        onClick={lambda {
                            register = not register;
                            error = "";
                        }}
                    >
                        {"Already have an account? Sign in"
                            if register
                            else "New here? Create an account"}
                    </button>
                </form>
                    if modal == "auth"
                    else None}
                {<form onSubmit={save}>
                    <label>
                        Title
                        <input
                            autoFocus={True}
                            required={True}
                            maxLength={300}
                            placeholder="What would you like to do?"
                            value={title}
                            onChange={lambda (e: ChangeEvent) { title = e.target.value; }}
                        />
                    </label>
                    <div className="form-row">
                        <label>
                            Category
                            <select
                                value={category}
                                onChange={lambda (e: ChangeEvent) {
                                    category = e.target.value;
                                    if modal == "block" {
                                        kind = "gym"
                                            if category == "gym"
                                            else "travel"
                                                if category == "travel"
                                                else "session" if taskId else "event";
                                    }
                                }}
                            >
                                <option value="academics">Academics</option>
                                <option value="gym">Gym & wellbeing</option>
                                <option value="social/campus">Social & campus</option>
                                <option value="personal">Personal & work</option>
                                <option value="travel">Travel</option>
                            </select>
                        </label>
                        {<label>
                            Duration (minutes)
                            <input
                                type="number"
                                min="1"
                                max="10080"
                                required={True}
                                value={duration}
                                onChange={lambda (e: ChangeEvent) { duration = e.target.value; }}
                            />
                        </label>
                            if modal == "task" or modal == "editTask"
                            else <label>
                                Type
                                <select
                                    value={kind}
                                    onChange={lambda (e: ChangeEvent) {
                                        kind = e.target.value;
                                        if kind == "work" {
                                            location = "Evergreen Plymouth (2771 Plymouth Rd, Ann Arbor, MI 48105)";
                                            placeId = "";
                                            startTime = "16:30";
                                            endTime = "21:00";
                                            weekends = True;
                                        }
                                        category = "gym"
                                            if kind == "gym"
                                            else "travel"
                                                if kind == "travel"
                                                else "personal"
                                                    if kind == "work"
                                                    else "academics"
                                                        if category == "gym"
                                                            or category == "travel"
                                                        else category;
                                    }}
                                >
                                    <option value="event">Event</option>
                                    <option value="session">Task session</option>
                                    <option value="gym">Gym</option>
                                    <option value="work">Work shift</option>
                                    <option value="travel">Travel</option>
                                </select>
                            </label>}
                    </div>
                    {<div>
                        <label>
                            Date
                            <input
                                type="date"
                                required={True}
                                value={day}
                                onInput={lambda (e: any) { day = e.target.value; }}
                            />
                        </label>
                        <div className="form-row">
                            <label>
                                Start
                                <input
                                    type="time"
                                    required={True}
                                    value={startTime}
                                    onInput={lambda (e: any) { startTime = e.target.value; }}
                                />
                            </label>
                            <label>
                                End
                                <input
                                    type="time"
                                    required={True}
                                    value={endTime}
                                    onInput={lambda (e: any) { endTime = e.target.value; }}
                                />
                            </label>
                        </div>
                        <LocationPicker
                            value={location}
                            placeId={placeId}
                            onChange={lambda (text: str, id: str) {
                                location = text;
                                placeId = id;
                            }}
                        />
                        {<div className="gym-choices">
                            <span>Choose your gym</span>
                            <button
                                type="button"
                                onClick={lambda {
                                    location = "Hadley Rec Center, Ann Arbor, MI";
                                    placeId = "";
                                }}
                            >
                                Hadley · Central Campus
                            </button>
                            <button
                                type="button"
                                onClick={lambda {
                                    location = "North Campus Recreation Building (NCRB), Ann Arbor, MI";
                                    placeId = "";
                                }}
                            >
                                NCRB · North Campus
                            </button>
                            <p className="form-hint">
                                Choose for this visit. The 10-minute walk to AHB applies to Hadley only.
                            </p>
                        </div>
                            if kind == "gym"
                            else None}
                        {<MapThumbnail location={location} placeId={placeId}/>
                            if location
                            else None}
                        {<div className="form-row">
                            <label>
                                From
                                <input
                                    required={True}
                                    value={origin}
                                    onChange={lambda (e: ChangeEvent) { origin = e.target.value; }}
                                />
                            </label>
                            <label>
                                To
                                <input
                                    required={True}
                                    value={destination}
                                    onChange={lambda (e: ChangeEvent) { destination = e.target.value; }}
                                />
                            </label>
                        </div>
                            if kind == "travel"
                            else None}
                        <p className="form-hint">
                            Times are in America/Detroit. Overlaps are checked before saving.
                        </p>
                    </div>
                        if modal == "block"
                        else None}
                    <button className="primary full" disabled={busy}>
                        {"Saving…"
                            if busy
                            else "Save task"
                                if modal == "task" or modal == "editTask"
                                else "Save time block"}
                        <Check size={16}/>
                    </button>
                </form>
                    if modal == "task" or modal == "editTask" or modal == "block"
                    else None}
                {<div className="event-details-layout">
                    <form onSubmit={move}>
                        <div className="detail-summary">
                            <span className={"tag " + tone(detail.category)}>
                                {detail.kind}
                            </span>
                            <p>
                                <MapPin size={15}/>
                                {detail.location or "No location set"}
                            </p>
                            <p>
                                <Clock3 size={15}/>
                                {clock(detail.start)}{" "}
                                –{" "}
                                {clock(detail.end)}
                            </p>
                        </div>
                        <LocationPicker
                            value={location}
                            placeId={placeId}
                            onChange={lambda (text: str, id: str) {
                                location = text;
                                placeId = id;
                            }}
                        />
                        {<div className="gym-choices">
                            <button
                                type="button"
                                onClick={lambda {
                                    location = "Hadley Rec Center, Ann Arbor, MI";
                                    placeId = "";
                                }}
                            >
                                Hadley
                            </button>
                            <button
                                type="button"
                                onClick={lambda {
                                    location = "North Campus Recreation Building (NCRB), Ann Arbor, MI";
                                    placeId = "";
                                }}
                            >
                                NCRB
                            </button>
                        </div>
                            if detail.kind == "gym"
                            else None}
                        <label>
                            Date
                            <input
                                type="date"
                                required={True}
                                value={day}
                                onInput={lambda (e: any) { day = e.target.value; }}
                            />
                        </label>
                        <div className="form-row">
                            <label>
                                Start
                                <input
                                    type="time"
                                    required={True}
                                    value={startTime}
                                    onInput={lambda (e: any) { startTime = e.target.value; }}
                                />
                            </label>
                            <label>
                                End
                                <input
                                    type="time"
                                    required={True}
                                    value={endTime}
                                    onInput={lambda (e: any) { endTime = e.target.value; }}
                                />
                            </label>
                        </div>
                        <p className="form-hint">
                            {"Changes affect this occurrence only."
                                if detail.kind == "class"
                                else "Linked travel moves with the activity."} Times in America/Detroit.
                        </p>
                        <button className="primary full" disabled={busy}>
                            {"Saving…" if busy else "Move time block"}
                        </button>
                    </form>
                    <MapThumbnail location={location} placeId={placeId}/>
                </div>
                    if modal == "detail"
                    else None}
            </section>
        </div>
            if modal
            else None}
    </div>
}
