"""Cadence native mobile: one authenticated service, with touch-first planning workflows."""
import from "@jac/mobui" {
    View,
    Text,
    Pressable,
    TextInput,
    ScrollView,
    Modal,
    RefreshControl,
    KeyboardAvoidingView,
    Platform,
    StatusBar,
    Image,
    Linking
}
import from .components.Safe { SafeRoot, SafeFrame }
import from .theme { C, styles, categoryColor }
import from .components.Button { Button }
import from .components.Field { Field }
import from .components.Icon { Icon }
import from .client { call, normalizeServer }
import from .session { initialServer, readSession, writeSession, clearSession }
import from ..shared.http { request }
import from ..shared.planning {
    today,
    monday,
    shift,
    label,
    clock,
    stamp,
    dateOf,
    previewWeek,
    previewTasks
}

def:pub app() -> JsxElement {
    has selected: str = today(),
        week: any = previewWeek(today()),
        tasks: any = previewTasks(),
        token: str = "",
        server: str = initialServer(),
        serverDraft: str = initialServer(),
        account: str = "",
        username: str = "",
        password: str = "",
        registering: bool = False,
        busy: bool = False,
        mode: str = "day",
        query: str = "",
        categoryFilter: str = "all",
        error: str = "",
        notice: str = "",
        modal: str = "",
        title: str = "",
        category: str = "personal",
        kind: str = "event",
        duration: str = "60",
        day: str = today(),
        endDay: str = today(),
        startTime: str = "17:30",
        endTime: str = "18:30",
        location: str = "",
        placeId: str = "",
        taskId: str = "",
        origin: str = "",
        destination: str = "",
        detail: any = None,
        deleteTarget: str = "",
        suggestions: any = [],
        mapUri: str = "",
        placeError: str = "",
        searchVersion: int = 0,
        searchTimer: any = None,
        placeSession: str = "",
        searchBusy: bool = False;

    async can with entry {
        try {
            saved = await readSession();
            if saved {
                server = saved.server;
                serverDraft = saved.server;
                token = saved.token;
                account = saved.account;
                tasks = [];
                week = {"days": [], "warnings": [], "work_weeks": []};
                await load(selected, saved.token, saved.server);
            }
        } except Exception {
            error = "Could not restore the session. Sign in again from Account.";
        }
    }
    async def load(date: str, auth: str, base: str) -> None {
        busy = True;
        error = "";
        try {
            freshWeek = await call(base, "get_week", {"day": date}, auth);
            freshTasks = await call(
                base, "list_tasks", {"include_completed": True}, auth
            );
            week = freshWeek;
            tasks = freshTasks;
            selected = date;
        } except Exception as e {
            error = str(e);
        } finally {
            busy = False;
        }
    }
    async def navigate(date: str) -> None {
        if token {
            await load(date, token, server);
        } else {
            selected = date;
            week = previewWeek(date);
        }
    }
    async def login() -> None {
        busy = True;
        error = "";
        try {
            base = normalizeServer(serverDraft);
            if not username.strip() or not password {
                raise Exception("Enter your username and password.");
            }
            payload: any = {
                "identity": {"type": "username", "value": username.strip()},
                "credential": {"type": "password", "password": password}
            };
            if registering {
                payload = {
                    "identities": [payload.identity],
                    "credential": payload.credential
                };
            }
            body = await request(
                base + ("/user/register" if registering else "/user/login"), payload
            );
            if not body.data or not body.data.token {
                raise Exception(
                    "The server did not return a session. Check its address."
                );
            }
            token = body.data.token;
            server = base;
            account = username.strip();
            password = "";
            await writeSession({"server": base, "token": token, "account": account});
            week = {"days": [], "warnings": [], "work_weeks": []};
            tasks = [];
            mode = "day";
            await load(selected, token, base);
        } except Exception as e {
            error = str(e);
        } finally {
            busy = False;
        }
    }
    async def logout() -> None {
        await clearSession();
        token = "";
        account = "";
        password = "";
        modal = "";
        deleteTarget = "";
        week = previewWeek(selected);
        tasks = previewTasks();
        error = "";
        notice = "Signed out. Preview data is temporary.";
    }
    def closeForm() -> None {
        clearTimeout(searchTimer);
        searchVersion += 1;
        modal = "";
        deleteTarget = "";
        suggestions = [];
        searchBusy = False;
    }
    def openForm(which: str) -> None {
        error = "";
        notice = "";
        detail = None;
        title = "";
        category = "personal";
        kind = "event";
        duration = "60";
        day = selected;
        endDay = selected;
        startTime = "17:30";
        endTime = "18:30";
        location = "";
        placeId = "";
        taskId = "";
        origin = "";
        destination = "";
        suggestions = [];
        mapUri = "";
        placeError = "";
        searchVersion += 1;
        placeSession = str(Date.now()) + "-" + str(Math.random()).replace(".", "");
        modal = which;
    }
    def workDefaults() -> None {
        kind = "work";
        category = "personal";
        title = title or "Restaurant shift";
        location = "Evergreen Plymouth (2771 Plymouth Rd, Ann Arbor, MI 48105)";
        placeId = "";
        mapUri = "";
        startTime = "16:30";
        endTime = "21:00";
    }
    async def mapFor(id: str, version: int) -> None {
        if not token or not id {
            return;
        }
        try {
            result = await call(server, "place_map", {"place_id": id}, token);
            if version == searchVersion {
                mapUri = result.image;
            }
        } except Exception as e {
            if version == searchVersion {
                placeError = str(e);
            }
        }
    }
    def inspect(block: any) -> None {
        openForm("event");
        detail = block;
        title = block.title;
        category = block.category;
        kind = block.kind;
        day = label(block.start, "yyyy-MM-dd");
        endDay = label(block.end, "yyyy-MM-dd");
        startTime = label(block.start, "HH:mm");
        endTime = label(block.end, "HH:mm");
        location = block.location or "";
        placeId = block.place_id or "";
        origin = block.origin or "";
        destination = block.destination or "";
        mapFor(placeId, searchVersion);
    }
    async def searchPlaces(text: str, version: int) -> None {
        if version != searchVersion {
            return;
        }
        searchBusy = True;
        try {
            result = await call(
                server,
                "search_places",
                {"query": text, "session_token": placeSession},
                token
            );
            if version == searchVersion {
                suggestions = result;
                if result.length == 0 {
                    placeError = "No matching places. You can keep the typed location.";
                }
            }
        } except Exception as e {
            if version == searchVersion {
                placeError = str(e);
            }
        } finally {
            if version == searchVersion {
                searchBusy = False;
            }
        }
    }
    def changeLocation(text: str) -> None {
        location = text;
        placeId = "";
        mapUri = "";
        suggestions = [];
        placeError = "";
        searchVersion += 1;
        clearTimeout(searchTimer);
        searchBusy = False;
        if token and len(text.strip()) >= 3 {
            version = searchVersion;
            searchTimer = setTimeout(lambda { searchPlaces(text, version); }, 450);
        }
    }
    async def choosePlace(place: any) -> None {
        searchVersion += 1;
        version = searchVersion;
        clearTimeout(searchTimer);
        suggestions = [];
        location = place.label;
        placeId = place.id;
        try {
            await call(
                server,
                "select_place",
                {"place_id": place.id, "session_token": placeSession},
                token
            );
        } except Exception as e {
            placeError = str(e);
        }
        if version != searchVersion {
            return;
        }
        placeSession = str(Date.now()) + "-" + str(Math.random()).replace(".", "");
        await mapFor(place.id, version);
    }
    async def save() -> None {
        busy = True;
        error = "";
        try {
            if not title.strip() {
                raise Exception(
                    "Give this "
                        + ("task" if modal == "task" else "event")
                        + " a title."
                );
            }
            if modal == "task" {
                minutes = Number(duration);
                if not Number.isInteger(minutes) or minutes < 1 or minutes > 10080 {
                    raise Exception(
                        "Duration must be a whole number from 1 to 10080 minutes."
                    );
                }
                changes: any = {
                    "title": title.strip(),
                    "category": category,
                    "duration_minutes": minutes
                };
                if token {
                    if detail {
                        await call(
                            server,
                            "update_task",
                            {
                                "task_id": detail.id,
                                "expected_revision": detail.revision,
                                "changes": changes
                            },
                            token
                        );
                    } else {
                        await call(server, "create_task", changes, token);
                    }
                } else {
                    if detail {
                        tasks = tasks.map(
                            lambda (t: any) { return {** t, ** changes}
                                if t.id == detail.id
                                else t; }
                        );
                    } else {
                        tasks = [
                            *tasks,
                            {
                                ** changes,
                                "id": str(Date.now()),
                                "completed": False,
                                "revision": 1,
                                "block_ids": []
                            }
                        ];
                    }
                }
            } else {
                start = stamp(day, startTime);
                end = stamp(endDay, endTime);
                if not start
                    or not end
                    or dateOf(end).toMillis() <= dateOf(start).toMillis() {
                    raise Exception(
                        "Enter valid dates (YYYY-MM-DD) and times (HH:mm), with end after start."
                    );
                }
                payload: any = {
                    "title": title.strip(),
                    "category": category,
                    "kind": kind,
                    "start": start,
                    "end": end,
                    "location": location,
                    "place_id": placeId,
                    "task_id": taskId,
                    "origin": origin,
                    "destination": destination
                };
                if token {
                    if detail {
                        move: any = {
                            "expected_revision": detail.revision,
                            "start": start,
                            "end": end,
                            "location": location,
                            "place_id": placeId
                        };
                        if detail.kind == "class" {
                            await call(
                                server,
                                "set_occurrence_exception",
                                {
                                    ** move,
                                    "series_id": detail.series_id,
                                    "occurrence_date": detail.occurrence_date,
                                    "action": "move"
                                },
                                token
                            );
                        } else {
                            await call(
                                server,
                                "move_block",
                                {** move, "block_id": detail.id},
                                token
                            );
                        }
                    } else {
                        await call(server, "create_block", payload, token);
                    }
                } else {
                    if detail {
                        raise Exception(
                            "Sign in to change saved commitments. Preview events are examples."
                        );
                    }
                    if day != endDay {
                        raise Exception(
                            "Sign in to save an event spanning multiple dates."
                        );
                    }
                    current = week.days.find(lambda (d: any) { return d.date == day; });
                    if not current {
                        raise Exception(
                            "Choose a date in this preview week, or sign in to save another date."
                        );
                    }
                    if current.blocks.some(
                        lambda (b: any) { return dateOf(b.start).toMillis()
                            < dateOf(end).toMillis()
                            and dateOf(b.end).toMillis() > dateOf(start).toMillis(); }
                    ) {
                        raise Exception("This event overlaps an existing commitment.");
                    }
                    week = {
                        ** week,
                        "days": week.days.map(
                            lambda (d: any) { return {
                                ** d,
                                "blocks": [
                                    *d.blocks,
                                    {** payload, "id": str(Date.now()), "revision": 1}
                                ]
                            }
                                if d.date == day
                                else d; }
                        )
                    };
                    selected = day;
                }
            }
            savedDay = day if modal == "event" else selected;
            closeForm();
            notice = "Saved to your planner."
                if token
                else "Added to this preview only. Sign in to keep it.";
            if token {
                await load(savedDay, token, server);
            }
        } except Exception as e {
            error = str(e);
        } finally {
            busy = False;
        }
    }
    async def removeSelected() -> None {
        if not detail or deleteTarget != detail.id {
            return;
        }
        busy = True;
        error = "";
        try {
            deletingTask = modal == "task";
            if token {
                if deletingTask {
                    await call(
                        server,
                        "remove_task",
                        {"task_id": detail.id, "expected_revision": detail.revision},
                        token
                    );
                } elif detail.kind == "class" {
                    await call(
                        server,
                        "set_occurrence_exception",
                        {
                            "series_id": detail.series_id,
                            "occurrence_date": detail.occurrence_date,
                            "expected_revision": detail.revision,
                            "action": "cancel"
                        },
                        token
                    );
                } else {
                    await call(
                        server,
                        "remove_block",
                        {
                            "block_id": detail.id,
                            "expected_revision": detail.revision,
                            "include_linked_travel": True
                        },
                        token
                    );
                }
            } else {
                if deletingTask {
                    tasks = tasks.filter(lambda (t: any) { return t.id != detail.id; });
                    week = {
                        ** week,
                        "days": week.days.map(
                            lambda (d: any) { return {
                                ** d,
                                "blocks": d.blocks.map(
                                    lambda (b: any) { return {** b, "task_id": ""}
                                        if b.task_id == detail.id
                                        else b; }
                                )
                            }; }
                        )
                    };
                } else {
                    week = {
                        ** week,
                        "days": week.days.map(
                            lambda (d: any) { return {
                                ** d,
                                "blocks": d.blocks.filter(
                                    lambda (b: any) { return b.id != detail.id
                                        and b.linked_to != detail.id; }
                                )
                            }; }
                        )
                    };
                }
            }
            modal = "";
            deleteTarget = "";
            notice = (
                "Task deleted. Scheduled sessions remain on your calendar."
                    if deletingTask
                    else "Event removed from this date."
            )
                if token
                else "Deleted from this preview only.";
            if token {
                await load(selected, token, server);
            }
        } except Exception as e {
            error = str(e);
        } finally {
            busy = False;
        }
    }
    async def complete(task: any) -> None {
        busy = True;
        error = "";
        try {
            if token {
                await call(
                    server,
                    "update_task",
                    {
                        "task_id": task.id,
                        "expected_revision": task.revision,
                        "changes": {"completed": not task.completed}
                    },
                    token
                );
                await load(selected, token, server);
            } else {
                tasks = tasks.map(
                    lambda (t: any) { return {** t, "completed": not t.completed}
                        if t.id == task.id
                        else t; }
                );
            }
        } except Exception as e {
            error = str(e);
        } finally {
            busy = False;
        }
    }
    async def publication() -> None {
        busy = True;
        error = "";
        try {
            status = week.work_weeks[0];
            if token {
                await call(
                    server,
                    "set_work_week",
                    {
                        "week_start": status.week_start,
                        "expected_revision": status.revision,
                        "published": not status.published
                    },
                    token
                );
                await load(selected, token, server);
            } else {
                week = {
                    ** week,
                    "work_weeks": [{** status, "published": not status.published}]
                };
            }
        } except Exception as e {
            error = str(e);
        } finally {
            busy = False;
        }
    }
    categories: any = [
        ["all", "All"],
        ["academics", "Academics"],
        ["gym", "Gym"],
        ["social/campus", "Social"],
        ["personal", "Personal / work"],
        ["travel", "Travel"]
    ];
    tabs: any = [["day", "My week"], ["tasks", "Tasks"], ["account", "Account"]];
    kinds: any = [
        ["event", "Event"],
        ["session", "Task session"],
        ["gym", "Gym"],
        ["work", "Work shift"],
        ["travel", "Travel"]
    ];
    currentDay = week.days.find(lambda (d: any) { return d.date == selected; });
    dayBlocks: any = currentDay.blocks if currentDay else [];
    blocks: any = sorted(
        dayBlocks.filter(
            lambda (b: any) { return categoryFilter == "all"
                or b.category == categoryFilter; }
        ),
        key=lambda (b: any) { return dateOf(b.start).toMillis(); }
    );
    shownTasks = tasks.filter(
        lambda (t: any) { return (
            categoryFilter == "all" or t.category == categoryFilter
        )
            and t.title.toLowerCase().includes(query.lower())
            and (bool(t.completed) == (mode == "completed")); }
    );
    allBlocks = week.days.flatMap(lambda (d: any) { return d.blocks; });
    gymCount = week.days.filter(
        lambda (d: any) { return dateOf(d.date).weekday <= 5
            and d.blocks.some(lambda (b: any) { return b.kind == "gym"; }); }
    ).length;
    workStatus = week.work_weeks[0];
    <SafeRoot>
        <SafeFrame style={styles.screen} edges={["top", "bottom"]}>
            <StatusBar barStyle="dark-content"/>
            <ScrollView
                style={{"flex": 1}}
                contentContainerStyle={styles.body}
                keyboardShouldPersistTaps="handled"
                refreshControl={<RefreshControl
                    refreshing={busy}
                    onRefresh={lambda { navigate(selected); }}
                    tintColor={C.accent}
                />}
            >
                <View style={styles.between}>
                    <Text
                        style={{"fontSize": 29, "fontWeight": "800", "color": C.text}}
                    >
                        cadence
                        <Text style={{"color": C.accent}}>.</Text>
                    </Text>
                    <Pressable
                        accessibilityRole="button"
                        accessibilityLabel="Refresh planner"
                        onPress={lambda { navigate(selected); }}
                        style={styles.pill}
                    >
                        <Text style={{"color": C.accent}}>↻ Refresh</Text>
                    </Pressable>
                </View>
                {<View style={styles.banner}>
                    <Text style={styles.text}>A little space for life.</Text>
                    <Text style={styles.muted}>
                        Preview · Classes, suggested gym visits, and sample tasks. Changes are temporary.
                    </Text>
                    <Button
                        label="Sign in to your planner"
                        variant="secondary"
                        onPress={lambda { mode = "account"; }}
                    />
                </View>
                    if not token and mode != "account"
                    else <View/>}
                {<View accessibilityRole="alert" style={styles.error}>
                    <Text style={styles.text}>{error}</Text>
                    <Button
                        label="Dismiss"
                        variant="secondary"
                        onPress={lambda { error = ""; }}
                    />
                </View>
                    if error and not modal
                    else <View/>}
                {<View style={styles.banner}>
                    <Text style={styles.text}>{notice}</Text>
                </View>
                    if notice
                    else <View/>}
                {<View style={{"gap": 18}}>
                    <Text style={styles.eyebrow}>YOUR WEEK, IN BALANCE</Text>
                    <Text style={styles.title}>{label(selected, "EEEE, MMM d")}</Text>
                    <View style={styles.row}>
                        <View style={styles.stat}>
                            <Text style={styles.heading}>
                                {str(
                                    allBlocks.filter(
                                        lambda (b: any) { return b.kind == "class"; }
                                    ).length
                                )}
                            </Text>
                            <Text style={styles.muted}>Class meetings</Text>
                        </View>
                        <View style={styles.stat}>
                            <Text style={styles.heading}>{str(gymCount)} / 5</Text>
                            <Text style={styles.muted}>Gym days</Text>
                        </View>
                        <View style={styles.stat}>
                            <Text style={styles.heading}>
                                {str(
                                    tasks.filter(
                                        lambda (t: any) { return t.completed; }
                                    ).length
                                )}
                            </Text>
                            <Text style={styles.muted}>Tasks done</Text>
                        </View>
                    </View>
                    <View style={styles.between}>
                        <Button
                            label="‹ Week"
                            variant="secondary"
                            disabled={busy}
                            onPress={lambda { navigate(shift(selected, -7)); }}
                        />
                        <Button
                            label="Today"
                            variant="secondary"
                            disabled={busy}
                            onPress={lambda { navigate(today()); }}
                        />
                        <Button
                            label="Week ›"
                            variant="secondary"
                            disabled={busy}
                            onPress={lambda { navigate(shift(selected, 7)); }}
                        />
                    </View>
                    <ScrollView
                        horizontal={True}
                        showsHorizontalScrollIndicator={False}
                        contentContainerStyle={{"gap": 8}}
                    >
                        {week.days.map(
                            lambda (d: any) { return
                                <Pressable
                                    key={d.date}
                                    accessibilityRole="button"
                                    accessibilityLabel={"Show "
                                        + label(d.date, "EEEE MMMM d")}
                                    accessibilityState={{
                                        "selected": selected == d.date
                                    }}
                                    style={[
                                        styles.pill,
                                        styles.active if selected == d.date else {}
                                    ]}
                                    onPress={lambda { selected = d.date; }}
                                >
                                    <Text style={styles.muted}>
                                        {label(d.date, "ccc")}
                                    </Text>
                                    <Text
                                        style={[
                                            styles.heading,
                                            {"textAlign": "center", "color": C.accent}
                                        ]}
                                    >
                                        {label(d.date, "d")}
                                    </Text>
                                </Pressable>; }
                        )}
                    </ScrollView>
                    <Button
                        label="＋ Create event"
                        disabled={busy}
                        onPress={lambda { openForm("event"); }}
                    />
                    <ScrollView
                        horizontal={True}
                        showsHorizontalScrollIndicator={False}
                        contentContainerStyle={{"gap": 8}}
                    >
                        {categories.map(
                            lambda (c: any) { return
                                <Pressable
                                    key={c[0]}
                                    accessibilityRole="button"
                                    accessibilityState={{
                                        "selected": categoryFilter == c[0]
                                    }}
                                    style={[
                                        styles.pill,
                                        styles.active if categoryFilter == c[0] else {}
                                    ]}
                                    onPress={lambda { categoryFilter = c[0]; }}
                                >
                                    <Text style={styles.text}>{c[1]}</Text>
                                </Pressable>; }
                        )}
                    </ScrollView>
                    <Text style={styles.heading}>Day agenda</Text>
                    <Text style={styles.muted}>
                        America/Detroit · Classes end 10 minutes early
                    </Text>
                    {blocks.map(
                        lambda (b: any) { return
                            <Pressable
                                key={b.id}
                                accessibilityRole="button"
                                accessibilityLabel={b.title + ", " + clock(b.start)}
                                onPress={lambda { inspect(b); }}
                                style={[
                                    styles.event,
                                    {"borderLeftColor": categoryColor(b.category)}
                                ]}
                            >
                                <Text
                                    style={[
                                        styles.muted,
                                        {"color": categoryColor(b.category)}
                                    ]}
                                >
                                    {clock(b.start)} – {clock(b.end)}{(
                                        " · ends " + label(b.end, "MMM d")
                                    )
                                        if label(b.end, "yyyy-MM-dd")
                                            != label(b.start, "yyyy-MM-dd")
                                        else ""}
                                </Text>
                                <Text style={styles.heading}>{b.title}</Text>
                                <Text style={styles.muted}>
                                    {b.location or "No location set"}
                                </Text>
                                <Text
                                    style={[
                                        styles.muted,
                                        {"color": categoryColor(b.category)}
                                    ]}
                                >
                                    {b.category} · {b.kind}
                                </Text>
                            </Pressable>; }
                    )}
                    {<View style={styles.card}>
                        <Text style={styles.heading}>Room to breathe.</Text>
                        <Text style={styles.muted}>
                            No events in this view. Your free time belongs here, too.
                        </Text>
                    </View>
                        if blocks.length == 0
                        else <View/>}
                    {<View style={styles.card}>
                        <Text style={styles.heading}>Restaurant shifts</Text>
                        <Text style={styles.muted}>
                            {"Schedule published. Enter the actual dated shifts."
                                if workStatus.published
                                else "Awaiting next schedule · expected Friday, "
                                    + label(workStatus.publication_date, "MMM d")}
                        </Text>
                        <Text style={styles.text}>Evergreen Plymouth</Text>
                        <Text style={styles.muted}>
                            2771 Plymouth Rd, Ann Arbor, MI 48105 · ~2 shifts/week, including weekends. Default 16:30–21:00; times are editable.
                        </Text>
                        <Button
                            label="＋ Add a shift"
                            disabled={busy}
                            onPress={lambda {
                                openForm("event");
                                workDefaults();
                            }}
                        />
                        <Button
                            label={"Mark as pending"
                                if workStatus.published
                                else "Mark schedule published"}
                            variant="secondary"
                            disabled={busy}
                            onPress={lambda { publication(); }}
                        />
                    </View>
                        if workStatus
                        else <View/>}
                    {<View style={styles.banner}>
                        <Text style={styles.heading}>Planning notes</Text>
                        {week.warnings.slice(0, 8).map(
                            lambda (w: any, i: int) { return
                                <Text key={i} style={styles.muted}>
                                    {w.message
                                        or (
                                            "Plan a gym visit"
                                                if w.code == "missing_gym"
                                                else "Check travel time"
                                                    if w.code == "travel_unverified"
                                                    else w.code.replace("_", " ")
                                        )}{(" · " + w.date) if w.date else ""}
                                </Text>; }
                        )}
                    </View>
                        if week.warnings.length
                        else <View/>}
                </View>
                    if mode == "day"
                    else <View/>}
                {<View style={{"gap": 16}}>
                    <Text style={styles.eyebrow}>CAPTURE IT. MAKE TIME FOR IT.</Text>
                    <Text style={styles.title}>
                        {"Completed" if mode == "completed" else "Task inbox"}
                    </Text>
                    <View style={styles.row}>
                        <Button
                            label="Active tasks"
                            variant="secondary"
                            onPress={lambda { mode = "tasks"; }}
                        />
                        <Button
                            label="Completed"
                            variant="secondary"
                            onPress={lambda { mode = "completed"; }}
                        />
                    </View>
                    <Field
                        label="Search tasks"
                        value={query}
                        onChange={lambda (v: str) { query = v; }}
                    />
                    <Button
                        label="＋ Create task"
                        disabled={busy}
                        onPress={lambda { openForm("task"); }}
                    />
                    <Text style={styles.muted}>
                        Task search leaves your calendar unchanged.
                    </Text>
                    <ScrollView horizontal={True} contentContainerStyle={{"gap": 8}}>
                        {categories.map(
                            lambda (c: any) { return
                                <Pressable
                                    key={c[0]}
                                    accessibilityRole="button"
                                    style={[
                                        styles.pill,
                                        styles.active if categoryFilter == c[0] else {}
                                    ]}
                                    onPress={lambda { categoryFilter = c[0]; }}
                                >
                                    <Text style={styles.text}>{c[1]}</Text>
                                </Pressable>; }
                        )}
                    </ScrollView>
                    {shownTasks.map(
                        lambda (t: any) { return
                            <View key={t.id} style={styles.card}>
                                <Pressable
                                    accessibilityRole="button"
                                    accessibilityLabel={"Edit " + t.title}
                                    onPress={lambda {
                                        openForm("task");
                                        detail = t;
                                        title = t.title;
                                        category = t.category;
                                        duration = str(t.duration_minutes);
                                    }}
                                >
                                    <Text style={styles.heading}>{t.title}</Text>
                                </Pressable>
                                <Text
                                    style={[
                                        styles.muted,
                                        {"color": categoryColor(t.category)}
                                    ]}
                                >
                                    {t.category} · {str(t.duration_minutes)} min
                                </Text>
                                <View style={styles.row}>
                                    <Button
                                        label={"Mark active"
                                            if t.completed
                                            else "Complete task"}
                                        variant="secondary"
                                        disabled={busy}
                                        onPress={lambda { complete(t); }}
                                    />
                                    {<Button
                                        label="Schedule session"
                                        variant="secondary"
                                        disabled={busy}
                                        onPress={lambda {
                                            openForm("event");
                                            title = t.title;
                                            category = t.category;
                                            kind = t.category
                                                if t.category in ["gym", "travel"]
                                                else "session";
                                            taskId = t.id;
                                            endTime = dateOf(
                                                stamp(day, startTime)
                                            ).plus(
                                                {"minutes": t.duration_minutes}
                                            ).toFormat(
                                                "HH:mm"
                                            );
                                            endDay = dateOf(stamp(day, startTime)).plus(
                                                {"minutes": t.duration_minutes}
                                            ).toISODate();
                                        }}
                                    />
                                        if not t.completed
                                        else <View/>}
                                </View>
                            </View>; }
                    )}
                    {<View style={styles.card}>
                        <Text style={styles.heading}>No matching tasks</Text>
                        <Text style={styles.muted}>
                            Try another search or category, or capture something new.
                        </Text>
                    </View>
                        if shownTasks.length == 0
                        else <View/>}
                </View>
                    if mode == "tasks" or mode == "completed"
                    else <View/>}
                {<View style={styles.card}>
                    <Text style={styles.title}>
                        {"Your account" if token else "Welcome to Cadence."}
                    </Text>
                    {<View style={{"gap": 12}}>
                        <Text style={styles.heading}>{account}</Text>
                        <Text selectable={True} style={styles.muted}>{server}</Text>
                        <Text style={styles.text}>
                            Web and mobile share this account's planner. Pull down to refresh after changes on another device.
                        </Text>
                        <Button
                            label="Sign out"
                            variant="secondary"
                            onPress={lambda { logout(); }}
                        />
                    </View>
                        if token
                        else <View style={{"gap": 14}}>
                            <Text style={styles.muted}>
                                Use the same account as the web dashboard. On a phone, enter your computer's LAN address or deployed HTTPS server; localhost means the phone itself.
                            </Text>
                            <Field
                                label="Planner server URL"
                                value={serverDraft}
                                onChange={lambda (v: str) { serverDraft = v; }}
                                placeholder="https://your-planner.example"
                            />
                            <Field
                                label="Username"
                                value={username}
                                onChange={lambda (v: str) { username = v; }}
                            />
                            <Field
                                label="Password"
                                value={password}
                                onChange={lambda (v: str) { password = v; }}
                                secret={True}
                            />
                            <Button
                                label={"Create account" if registering else "Sign in"}
                                disabled={busy}
                                onPress={lambda { login(); }}
                            />
                            <Button
                                label={"Use existing account"
                                    if registering
                                    else "New here? Create an account"}
                                variant="secondary"
                                onPress={lambda { registering = not registering; }}
                            />
                        </View>}
                </View>
                    if mode == "account"
                    else <View/>}
                <Text style={[styles.muted, {"textAlign": "center"}]}>
                    Make room for life. A little structure. A lot of possibility.
                </Text>
            </ScrollView>
            <View style={styles.bottom}>
                {tabs.map(
                    lambda (tab: any) { return
                        <Pressable
                            key={tab[0]}
                            accessibilityRole="button"
                            accessibilityState={{
                                "selected": mode == tab[0]
                                    or (tab[0] == "tasks" and mode == "completed")
                            }}
                            onPress={lambda { mode = tab[0]; }}
                            style={[
                                styles.pill,
                                {"flex": 1, "alignItems": "center"},
                                styles.active
                                    if mode == tab[0]
                                        or (tab[0] == "tasks" and mode == "completed")
                                    else {}
                            ]}
                        >
                            <Text
                                style={{
                                    "color": C.accent,
                                    "fontSize": 14,
                                    "fontWeight": "600"
                                }}
                            >
                                {tab[1]}
                            </Text>
                        </Pressable>; }
                )}
            </View>
            <Modal
                visible={bool(modal)}
                animationType="slide"
                onRequestClose={lambda { if not busy { closeForm(); }}}
            >
                <SafeFrame style={styles.modal}>
                    <KeyboardAvoidingView
                        style={{"flex": 1}}
                        behavior={"padding" if Platform.OS == "ios" else "height"}
                    >
                        <ScrollView
                            contentContainerStyle={styles.body}
                            keyboardShouldPersistTaps="handled"
                        >
                            <View style={styles.between}>
                                <Text style={styles.heading}>
                                    {("Edit task" if detail else "Create task")
                                        if modal == "task"
                                        else (
                                            "Event details"
                                                if detail
                                                else "Create event"
                                        )}
                                </Text>
                                <Button
                                    label="Close"
                                    variant="secondary"
                                    disabled={busy}
                                    onPress={lambda { closeForm(); }}
                                />
                            </View>
                            {<View accessibilityRole="alert" style={styles.error}>
                                <Text style={styles.text}>{error}</Text>
                            </View>
                                if error
                                else <View/>}
                            {<Text style={styles.title}>{title}</Text>
                                if detail and modal == "event"
                                else <Field
                                    label="Title"
                                    value={title}
                                    onChange={lambda (v: str) { title = v; }}
                                />}
                            {<View style={{"gap": 10}}>
                                <Text style={styles.muted}>Category</Text>
                                <View style={styles.row}>
                                    {categories.slice(1).map(
                                        lambda (c: any) { return
                                            <Pressable
                                                key={c[0]}
                                                accessibilityRole="button"
                                                style={[
                                                    styles.pill,
                                                    styles.active
                                                        if category == c[0]
                                                        else {}
                                                ]}
                                                onPress={lambda {
                                                    category = c[0];
                                                    if modal == "event" {
                                                        kind = "gym"
                                                            if category == "gym"
                                                            else (
                                                                "travel"
                                                                    if category
                                                                        == "travel"
                                                                    else "event"
                                                            );
                                                    }
                                                }}
                                            >
                                                <Text style={styles.text}>{c[1]}</Text>
                                            </Pressable>; }
                                    )}
                                </View>
                            </View>
                                if not detail or modal == "task"
                                else <View/>}
                            {<Field
                                label="Duration in minutes"
                                value={duration}
                                onChange={lambda (v: str) { duration = v; }}
                                numeric={True}
                            />
                                if modal == "task"
                                else <View style={{"gap": 16}}>
                                    {<View style={styles.row}>
                                        {kinds.map(
                                            lambda (k: any) { return
                                                <Pressable
                                                    key={k[0]}
                                                    accessibilityRole="button"
                                                    style={[
                                                        styles.pill,
                                                        styles.active
                                                            if kind == k[0]
                                                            else {}
                                                    ]}
                                                    onPress={lambda {
                                                        kind = k[0];
                                                        if kind == "work" {
                                                            workDefaults();
                                                        } elif kind == "gym"
                                                            or kind == "travel" {
                                                            category = kind;
                                                        } elif category == "gym"
                                                            or category == "travel" {
                                                            category = "personal";
                                                        }
                                                    }}
                                                >
                                                    <Text style={styles.text}>
                                                        {k[1]}
                                                    </Text>
                                                </Pressable>; }
                                        )}
                                    </View>
                                        if not detail
                                        else <Text style={styles.muted}>
                                            {kind} · {category}
                                        </Text>}
                                    <Field
                                        label="Start date (YYYY-MM-DD)"
                                        value={day}
                                        onChange={lambda (v: str) {
                                            if endDay == day {
                                                endDay = v;
                                            }
                                            day = v;
                                        }}
                                    />
                                    <Field
                                        label="End date (YYYY-MM-DD)"
                                        value={endDay}
                                        onChange={lambda (v: str) { endDay = v; }}
                                    />
                                    <View style={styles.row}>
                                        <Field
                                            label="Start time (HH:mm)"
                                            value={startTime}
                                            onChange={lambda (v: str) { startTime = v; }}
                                        />
                                        <Field
                                            label="End time (HH:mm)"
                                            value={endTime}
                                            onChange={lambda (v: str) { endTime = v; }}
                                        />
                                    </View>
                                    <Field
                                        label="Location"
                                        value={location}
                                        onChange={lambda (v: str) { changeLocation(
                                            v
                                        ); }}
                                        placeholder="Search a place or enter an address"
                                    />
                                    {<View style={styles.row}>
                                        <Button
                                            label="Hadley · Central"
                                            variant="secondary"
                                            onPress={lambda { changeLocation(
                                                "Hadley Rec Center, Ann Arbor, MI"
                                            ); }}
                                        />
                                        <Button
                                            label="NCRB · North"
                                            variant="secondary"
                                            onPress={lambda { changeLocation(
                                                "North Campus Recreation Building (NCRB), Ann Arbor, MI"
                                            ); }}
                                        />
                                        <Text style={styles.muted}>
                                            The 10-minute Walk to AHB applies to Hadley. Supply separate travel times for NCRB.
                                        </Text>
                                    </View>
                                        if kind == "gym"
                                        else <View/>}
                                    {<Text style={styles.muted}>Searching places…</Text>
                                        if searchBusy
                                        else <View/>}
                                    {<View style={styles.card}>
                                        {suggestions.map(
                                            lambda (p: any) { return
                                                <Button
                                                    key={p.id}
                                                    label={p.label}
                                                    variant="secondary"
                                                    onPress={lambda { choosePlace(p); }}
                                                />; }
                                        )}
                                        <Text
                                            style={{"fontSize": 13, "color": "#5e5e5e"}}
                                        >
                                            Google Maps
                                        </Text>
                                    </View>
                                        if suggestions.length
                                        else <View/>}
                                    {<Text style={styles.muted}>
                                        {placeError} You can still save a typed location.
                                    </Text>
                                        if placeError
                                        else <View/>}
                                    {<Image
                                        accessibilityLabel={"Map of " + location}
                                        source={{"uri": mapUri}}
                                        style={styles.map}
                                        resizeMode="contain"
                                    />
                                        if mapUri
                                        else <View/>}
                                    {<Button
                                        label="Open location in Google Maps ↗"
                                        variant="secondary"
                                        onPress={lambda { Linking.openURL(
                                            "https://www.google.com/maps/search/?api=1&query="
                                                + encodeURIComponent(location)
                                                + (
                                                    "&query_place_id="
                                                        + encodeURIComponent(placeId)
                                                        if placeId
                                                        else ""
                                                )
                                        ); }}
                                    />
                                        if location
                                        else <View/>}
                                    {<Text style={styles.muted}>
                                        Sign in to search Google places. Manual locations work in preview.
                                    </Text>
                                        if not token
                                        else <View/>}
                                    {<View style={{"gap": 12}}>
                                        <Field
                                            label="Travel origin"
                                            value={origin}
                                            onChange={lambda (v: str) { origin = v; }}
                                        />
                                        <Field
                                            label="Travel destination"
                                            value={destination}
                                            onChange={lambda (v: str) { destination = v; }}
                                        />
                                    </View>
                                        if kind == "travel" and not detail
                                        else <View/>}
                                    <Text style={styles.muted}>
                                        America/Detroit · {"Changes affect this class occurrence only."
                                            if kind == "class"
                                            else "Overlaps are checked by your server. Linked travel moves with its activity."}
                                    </Text>
                                </View>}
                            <Button
                                label={"Saving…"
                                    if busy
                                    else (
                                        "Save task"
                                            if modal == "task"
                                            else (
                                                "Save event changes"
                                                    if detail
                                                    else "Save event"
                                            )
                                    )}
                                disabled={busy}
                                onPress={lambda { save(); }}
                            />
                            {<View style={{"gap": 12, "paddingTop": 16}}>
                                {<View style={{"gap": 12}}>
                                    <Text style={styles.text}>
                                        {"Delete this task permanently? Scheduled sessions stay on the calendar as independent events."
                                            if modal == "task"
                                            else "Remove this class occurrence only? The rest of the series stays unchanged."
                                                if detail.kind == "class"
                                                else "Delete this event permanently? Any linked travel will also be deleted. The associated task stays in your inbox."}
                                    </Text>
                                    <Button
                                        label={"Deleting…"
                                            if busy
                                            else "Confirm delete"}
                                        variant="danger"
                                        disabled={busy}
                                        onPress={lambda { removeSelected(); }}
                                    />
                                    <Button
                                        label="Keep it"
                                        variant="secondary"
                                        disabled={busy}
                                        onPress={lambda { deleteTarget = ""; }}
                                    />
                                </View>
                                    if deleteTarget == detail.id
                                    else <Button
                                        label={"Delete task"
                                            if modal == "task"
                                            else "Remove this occurrence"
                                                if detail.kind == "class"
                                                else "Delete event"}
                                        variant="danger"
                                        disabled={busy}
                                        onPress={lambda { deleteTarget = detail.id; }}
                                    />}
                            </View>
                                if detail
                                else <View/>}
                        </ScrollView>
                    </KeyboardAvoidingView>
                </SafeFrame>
            </Modal>
        </SafeFrame>
    </SafeRoot>
}
