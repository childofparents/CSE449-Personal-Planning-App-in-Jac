"""Real HTTP tests in a temporary Jac project/database, including process restart.

Run: python3 -m unittest discover -s tests -v
Only Python's standard library and the installed Jac CLI are required.
"""
import concurrent.futures
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import tempfile
import time
import unittest
import urllib.error
import urllib.request
import uuid


class ServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="planner-server-test-")
        cls.project = Path(cls.temp.name)
        source = Path(__file__).resolve().parents[1]
        shutil.copytree(source / "core", cls.project / "core", ignore=shutil.ignore_patterns(".jac", "__pycache__"))
        shutil.copy(source / "jac.toml", cls.project / "jac.toml")
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            cls.port = sock.getsockname()[1]
        cls.base = f"http://127.0.0.1:{cls.port}"
        cls.log = open(cls.project / "server.log", "w+")
        cls.process = None
        cls.addClassCleanup(cls.cleanup)
        cls.start()

    @classmethod
    def start(cls):
        env = os.environ.copy()
        # Never attach an isolated test project to a user's external database.
        env.pop("JAC_DB_URL", None)
        env.pop("GOOGLE_MAPS_SERVER_API_KEY", None)
        cls.process = subprocess.Popen(
            ["jac", "run", "--port", str(cls.port), "--host", "127.0.0.1", "planner"],
            cwd=cls.project, stdout=cls.log, stderr=cls.log, env=env,
            start_new_session=True,
        )
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline:
            try:
                with urllib.request.urlopen(cls.base + "/healthz/ready", timeout=1) as r:
                    if r.status == 200:
                        return
            except (OSError, urllib.error.URLError):
                pass
            if cls.process.poll() is not None:
                break
            time.sleep(0.2)
        cls.log.flush()
        raise RuntimeError((cls.project / "server.log").read_text()[-10000:])

    @classmethod
    def stop(cls):
        if cls.process and cls.process.poll() is None:
            os.killpg(cls.process.pid, signal.SIGTERM)
            try:
                cls.process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                os.killpg(cls.process.pid, signal.SIGKILL)
                cls.process.wait(timeout=5)

    @classmethod
    def cleanup(cls):
        cls.stop()
        cls.log.close()
        cls.temp.cleanup()

    @classmethod
    def post(cls, path, payload, token=None):
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        request = urllib.request.Request(cls.base + path, json.dumps(payload).encode(), headers)
        try:
            with urllib.request.urlopen(request, timeout=20) as r:
                return r.status, json.load(r)
        except urllib.error.HTTPError as e:
            with e:
                return e.code, json.load(e)

    def setUp(self):
        self.username = "test-" + uuid.uuid4().hex
        status, body = self.post("/user/register", {
            "identities": [{"type": "username", "value": self.username}],
            "credential": {"type": "password", "password": "Test-password-927!"},
        })
        self.assertLess(status, 300, body)
        self.token = body["data"]["token"]

    def call(self, name, **payload):
        status, body = self.post("/function/" + name, payload, self.token)
        self.assertEqual(status, 200, body)
        self.assertTrue(body["ok"], body)
        return body["data"]["result"]

    def good(self, name, **payload):
        result = self.call(name, **payload)
        self.assertTrue(result["ok"], result)
        return result["data"]

    def bad(self, code, name, **payload):
        result = self.call(name, **payload)
        self.assertFalse(result["ok"], result)
        self.assertEqual(result["error"]["code"], code, result)
        return result["error"]

    def block(self, **overrides):
        args = dict(title="Focus", start="2026-09-14T17:30:00-04:00", end="2026-09-14T18:00:00-04:00")
        args.update(overrides)
        return self.good("create_block", **args)

    def test_auth_and_user_isolation(self):
        self.assertEqual(self.post("/function/list_tasks", {})[0], 401)
        task = self.good("create_task", title="Private task")
        self.setUp()  # a second, independently authenticated user
        self.assertEqual(self.good("list_tasks"), [])
        self.bad("not_found", "complete_task", task_id=task["id"], expected_revision=1)
        self.assertIn(self.post("/function/_state", {}, self.token)[0], (404, 405))

    def test_tasks_revisions_completion_and_sessions(self):
        self.bad("validation", "create_task", title=" ")
        self.bad("validation", "create_task", title="Bad category", category="made-up")
        task = self.good("create_task", title="Assignment", category="academics", duration_minutes=60)
        block = self.block(task_id=task["id"], kind="session", category="academics")
        self.good("complete_block", block_id=block["id"], expected_revision=1)
        self.assertFalse(self.good("list_tasks")[0]["completed"])
        done = self.good("complete_task", task_id=task["id"], expected_revision=1)
        self.assertEqual(done["revision"], 2)
        self.assertEqual(self.good("complete_task", task_id=task["id"], expected_revision=2), done)
        self.bad("stale_revision", "update_task", task_id=task["id"], expected_revision=1, changes={"title": "Stale"})
        self.bad("validation", "update_task", task_id=task["id"], expected_revision=2, changes={"completed": "false"})

    def test_classes_dst_semester_and_seed(self):
        for _ in range(2):
            week = self.good("get_week", day="2026-09-14")
            self.assertEqual(sum(len(d["blocks"]) for d in week["days"]), 8)
        self.assertEqual(week["days"][0]["blocks"][0]["end"], "2026-09-14T19:20:00+00:00")
        november = self.good("get_day", day="2026-11-02")["days"][0]["blocks"]
        self.assertEqual(november[0]["start"], "2026-11-02T18:30:00+00:00")
        self.assertEqual(self.good("get_day", day="2026-12-14")["days"][0]["blocks"], [])
        self.assertEqual(self.good("get_day", day="2026-08-24")["days"][0]["blocks"], [])
        self.bad("validation", "get_day", day="2026-02-30")

    def test_overlap_adjacency_and_failed_move_rollback(self):
        error = self.bad("overlap", "create_block", title="Overlap class", start="2026-09-14T14:00:00-04:00", end="2026-09-14T15:00:00-04:00")
        self.assertEqual(error["details"][0]["conflicting_id"], "eecs449:2026-09-14")
        a = self.block()
        self.block(start="2026-09-14T18:00:00-04:00", end="2026-09-14T18:30:00-04:00")
        self.bad("overlap", "move_block", block_id=a["id"], expected_revision=1, start="2026-09-14T13:30:00-04:00", end="2026-09-14T14:00:00-04:00")
        saved = {b["id"]: b for b in self.good("get_day", day="2026-09-14")["days"][0]["blocks"]}
        self.assertEqual(saved[a["id"]], a)
        self.bad("validation", "create_block", title="Naive", start="2026-09-14T19:00:00", end="2026-09-14T20:00:00")

    def test_gym_travel_atomic_moves(self):
        gym = self.block(title="Gym", kind="gym", category="gym", location="gym", start="2026-09-15T09:00:00-04:00", end="2026-09-15T10:45:00-04:00")
        travel = self.block(title="Walk to AAS", kind="travel", category="travel", origin="gym", destination="AHB", linked_to=gym["id"], start="2026-09-15T10:45:00-04:00", end="2026-09-15T10:55:00-04:00")
        self.bad("route_required", "move_block", block_id=gym["id"], expected_revision=1, start=gym["start"], end=gym["end"], location="another gym")
        self.bad("overlap", "move_block", block_id=gym["id"], expected_revision=1, start="2026-09-15T09:40:00-04:00", end="2026-09-15T11:25:00-04:00")
        day = self.good("get_day", day="2026-09-15")["days"][0]
        saved = {b["id"]: b for b in day["blocks"]}
        self.assertEqual(saved[travel["id"]], travel)
        moved = self.good("move_block", block_id=gym["id"], expected_revision=1, start="2026-09-15T09:10:00-04:00", end="2026-09-15T10:55:00-04:00")
        self.assertEqual(moved["linked_travel"][0]["start"], "2026-09-15T14:55:00+00:00")
        self.assertTrue(day["gym"]["planned"])
        self.assertFalse(day["gym"]["completed"])
        self.bad("linked_travel", "remove_block", block_id=gym["id"], expected_revision=2)
        self.good("remove_block", block_id=travel["id"], expected_revision=2)
        self.good("remove_block", block_id=gym["id"], expected_revision=2)
        self.good("create_task", title="Unscheduled gym", category="gym")
        self.assertFalse(self.good("get_day", day="2026-09-15")["days"][0]["gym"]["planned"])

    def test_exceptions_cross_week_and_restoration(self):
        args = dict(series_id="eecs449", occurrence_date="2026-09-14", expected_revision=0)
        self.good("set_occurrence_exception", **args, action="move", start="2026-09-22T14:00:00-04:00", end="2026-09-22T15:50:00-04:00")
        moved = self.good("get_day", day="2026-09-22")["days"][0]["blocks"]
        self.assertIn("eecs449:2026-09-14", [b["id"] for b in moved])
        args["expected_revision"] = 1
        self.good("set_occurrence_exception", **args, action="cancel")
        self.assertEqual(len(self.good("get_day", day="2026-09-14")["days"][0]["blocks"]), 1)
        args["expected_revision"] = 2
        self.good("set_occurrence_exception", **args, action="restore")
        self.assertEqual(len(self.good("get_day", day="2026-09-14")["days"][0]["blocks"]), 2)
        self.bad("stale_revision", "set_occurrence_exception", **args, action="cancel")

    def test_preferences_and_variable_work(self):
        preferences = self.good("get_preferences")
        self.assertEqual(preferences["gym_budget_minutes"], 150)
        self.assertEqual(preferences["usual_gym_departure"], "10:45")
        self.good("update_preferences", expected_revision=1, changes={"gym_budget_minutes": 140})
        self.bad("stale_revision", "update_preferences", expected_revision=1, changes={"gym_budget_minutes": 130})
        self.bad("validation", "update_preferences", expected_revision=2, changes={"gym_weekdays": [7]})
        week = self.good("get_week", day="2026-09-14")
        self.assertEqual(week["work_weeks"][0]["status"], "awaiting_publication")
        self.good("set_work_week", week_start="2026-09-14", expected_revision=0, published=True)
        self.block(title="Restaurant", kind="work", start="2026-09-19T16:00:00-04:00", end="2026-09-19T22:00:00-04:00")
        next_week = self.good("get_week", day="2026-09-21")
        self.assertEqual(next_week["work_weeks"][0]["status"], "awaiting_publication")
        self.assertFalse(any(b["kind"] == "work" for d in next_week["days"] for b in d["blocks"]))

    def test_place_identity_and_manual_location_changes(self):
        block = self.block(location="Hadley Rec Center", place_id="test-place-hadley")
        moved = self.good("move_block", block_id=block["id"], expected_revision=1,
                          start=block["start"], end=block["end"])["block"]
        self.assertEqual(moved["place_id"], "test-place-hadley")
        moved = self.good("move_block", block_id=block["id"], expected_revision=2,
                          start=block["start"], end=block["end"], location="NCRB")["block"]
        self.assertEqual(moved["place_id"], "")
        moved = self.good("move_block", block_id=block["id"], expected_revision=3,
                          start=block["start"], end=block["end"], location="NCRB", place_id="test-place-ncrb")["block"]
        self.assertEqual(moved["place_id"], "test-place-ncrb")
        self.bad("validation", "create_block", title="Missing address", start="2026-09-20T10:00:00-04:00",
                 end="2026-09-20T11:00:00-04:00", place_id="test-place")
        day = self.good("get_day", day="2026-09-14")
        self.assertTrue(any(b.get("place_id") == "test-place-ncrb" for b in day["days"][0]["blocks"]))

    def test_weekend_shift_defaults_and_gym_choices(self):
        prefs = self.good("get_preferences")
        self.assertEqual(prefs["work_possible_weekdays"], list(range(7)))
        self.assertEqual((prefs["work_default_start"], prefs["work_default_end"]), ("16:30", "21:00"))
        self.assertIn("North Campus Recreation Building (NCRB)", prefs["gym_locations"])
        for date in ("2026-09-19", "2026-09-20"):
            block = self.block(kind="work", start=date + "T16:30:00-04:00", end=date + "T21:00:00-04:00")
            self.assertEqual(block["location"], "Evergreen Plymouth (2771 Plymouth Rd, Ann Arbor, MI 48105)")
        self.assertEqual(prefs["routes"][0]["origin"], "Hadley Rec Center")
        self.assertEqual(prefs["routes"][0]["destination"], "AHB")

    def test_concurrent_overlap_and_stale_writes(self):
        payload = dict(title="Race", start="2026-09-20T12:00:00-04:00", end="2026-09-20T13:00:00-04:00")
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda _: self.call("create_block", **payload), range(2)))
        self.assertEqual(sum(r["ok"] for r in results), 1, results)
        self.assertEqual([r["error"]["code"] for r in results if not r["ok"]], ["overlap"])
        task = self.good("create_task", title="Concurrent edits")
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda title: self.call("update_task", task_id=task["id"], expected_revision=1, changes={"title": title}), ["Web", "Phone"]))
        self.assertEqual(sum(r["ok"] for r in results), 1, results)
        self.assertEqual([r["error"]["code"] for r in results if not r["ok"]], ["stale_revision"])

    def test_concurrent_first_use_keeps_one_planner(self):
        for _ in range(4):
            self.setUp()
            with concurrent.futures.ThreadPoolExecutor(6) as pool:
                results = list(pool.map(lambda i: self.post("/function/create_task", {"title": f"Capture {i}"}, self.token), range(6)))
            successful = []
            for status, body in results:
                self.assertIn(status, (200, 409), body)
                if status == 200:
                    self.assertTrue(body["data"]["result"]["ok"], body)
                    successful.append(body["data"]["result"]["data"])
                else:
                    self.assertEqual(body["error"]["code"], "WRITE_CONFLICT", body)
            self.assertTrue(successful)
            saved = self.good("list_tasks")
            self.assertEqual({t["id"] for t in saved}, {t["id"] for t in successful})

    def test_midnight_and_travel_warnings(self):
        gym = self.block(title="Late gym", category="gym", kind="gym", location="gym", start="2026-09-14T23:30:00-04:00", end="2026-09-15T00:30:00-04:00")
        self.assertTrue(self.good("get_day", day="2026-09-14")["days"][0]["gym"]["planned"])
        tuesday = self.good("get_day", day="2026-09-15")
        self.assertFalse(tuesday["days"][0]["gym"]["planned"])
        self.assertIn(gym["id"], [b["id"] for b in tuesday["days"][0]["blocks"]])
        self.block(title="Morning gym", category="gym", kind="gym", location="gym", start="2026-09-15T09:00:00-04:00", end="2026-09-15T10:45:00-04:00")
        self.block(title="Direct walk", category="travel", kind="travel", origin="gym", destination="AHB", start="2026-09-15T10:45:00-04:00", end="2026-09-15T10:55:00-04:00")
        warnings = self.good("get_day", day="2026-09-15")["warnings"]
        self.assertNotIn("aas254:2026-09-15", [w.get("block_id") for w in warnings if w["code"] == "travel_unverified"])

    def test_all_planner_endpoints_require_authentication(self):
        with urllib.request.urlopen(self.base + "/openapi.json") as response:
            paths = json.load(response)["paths"]
        endpoints = [p for p in paths if p.startswith("/function/") and "{" not in p]
        self.assertEqual(len(endpoints), 20, endpoints)
        self.assertFalse(any(p.endswith(("/uuid4", "/deepcopy")) for p in endpoints))
        valid = dict(query="Hadley", session_token="qa-session", place_id="test-place", day="2026-09-14", title="Test", start="2026-09-14T20:00:00-04:00",
                     end="2026-09-14T21:00:00-04:00", task_id="unknown", block_id="unknown",
                     expected_revision=1, changes={"title": "Test"}, series_id="eecs449",
                     occurrence_date="2026-09-14", action="cancel", week_start="2026-09-14", published=True)
        for path in endpoints:
            self.assertEqual(self.post(path, valid)[0], 401, path)

    def test_mobile_places_are_optional_and_validate_inputs(self):
        missing = self.bad("validation", "search_places", query="Hadley", session_token="qa-session")
        self.assertIn("not configured", missing["message"])
        self.bad("validation", "search_places", query="a", session_token="qa-session")
        self.bad("validation", "select_place", place_id="../escape", session_token="qa-session")
        self.bad("validation", "place_map", place_id="https://example.com")
        task = self.good("create_task", title="Planner still works without Google")
        self.assertEqual(task["title"], "Planner still works without Google")

    def test_z_persistence_after_server_restart(self):
        task = self.good("create_task", title="Survives restart")
        self.good("complete_task", task_id=task["id"], expected_revision=1)
        block = self.block(task_id=task["id"])
        self.good("update_preferences", expected_revision=1, changes={"gym_budget_minutes": 145})
        self.good("set_work_week", week_start="2026-09-14", expected_revision=0, published=True)
        self.good("set_occurrence_exception", series_id="eecs449", occurrence_date="2026-09-14", expected_revision=0, action="cancel")
        before = self.good("get_week", day="2026-09-14")
        type(self).stop()
        type(self).start()
        tasks = self.good("list_tasks")
        self.assertTrue(tasks[0]["completed"])
        self.assertEqual(tasks[0]["id"], task["id"])
        self.assertEqual(tasks[0]["block_ids"], [block["id"]])
        self.assertEqual(self.good("get_preferences")["gym_budget_minutes"], 145)
        self.assertEqual(self.good("get_week", day="2026-09-14"), before)


if __name__ == "__main__":
    unittest.main()
