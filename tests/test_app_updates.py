#!/usr/bin/env python3

import os
import fcntl
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "modules/darwin/app-updates.sh"


class AppUpdates(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.state = self.home / "Library/Application Support/app-updates"
        self.state.mkdir(parents=True)
        self.env = dict(os.environ, HOME=str(self.home), workstation="1", NOW="2000000000", DAY="20330518", YESTERDAY="20330517")
        self.env["PATH"] = f"{self.bin}:/usr/bin:/bin"
        self.command("date", 'if [[ "$1" == +%s ]]; then echo "$NOW"; elif [[ "$1" == -d ]]; then echo "$YESTERDAY"; else echo "$DAY"; fi')
        self.command("mas", 'case "$1" in list) echo "100 Example (1.0)";; outdated) printf "%s" "${PENDING:-}"; exit "${QUERY_EXIT:-0}";; update) exit "${UPDATE_EXIT:-0}";; esac')
        self.command("sudo", 'shift; "$@"')
        self.command("brew", 'exit "${UPDATE_EXIT:-0}"')
        self.command("notifier", 'cat >/dev/null; echo notified >> "$HOME/notices"; exit "${NOTICE_EXIT:-0}"')
        self.command("timeout", 'shift; shift; if [[ "${TIMED_OUT:-0}" == 1 ]]; then exit 124; fi; "$@"')
        for name in ("mas", "sudo", "brew", "notifier"):
            self.env[name] = str(self.bin / name)
        self.put("activated", 2000000000)

    def command(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/bash\nset -eu\n" + body + "\n")
        path.chmod(0o700)

    def put(self, name, value):
        (self.state / name).write_text(str(value) + "\n")

    def number(self, name):
        return int((self.state / name).read_text())

    def run_job(self, name, expected=0):
        result = subprocess.run(["/bin/bash", str(SCRIPT), name], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, expected, result.stderr)

    def notices(self):
        file = self.home / "notices"
        return len(file.read_text().splitlines()) if file.exists() else 0

    def test_success_and_snapshots(self):
        self.run_job("mas")
        self.assertEqual(self.number("mas.success"), 2000000000)
        for name in ("mas.before", "mas.after"):
            self.assertIn("Example", (self.home / "Library/Logs/app-updates" / name).read_text())
        self.run_job("health")
        self.assertEqual(self.notices(), 0)

    def test_authentication_failure_dedup_and_recovery(self):
        self.env["UPDATE_EXIT"] = "1"
        self.run_job("mas", 1)
        self.run_job("health")
        self.run_job("health")
        self.assertEqual(self.notices(), 1)
        self.env["UPDATE_EXIT"] = "0"
        self.run_job("mas")
        self.run_job("health")
        self.assertFalse((self.state / "mas.notified").exists())

    def test_timeout_and_brew_failure(self):
        self.env["TIMED_OUT"] = "1"
        self.run_job("mas", 124)
        self.assertEqual(self.number("mas.exit"), 124)
        self.run_job("brew", 124)
        self.assertFalse((self.state / "brew.success").exists())

    def test_live_lock_and_stale_lock(self):
        with (self.state / "mas.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            self.run_job("mas")
            self.assertFalse((self.state / "mas.attempt").exists())
        self.run_job("mas")
        self.assertEqual(self.number("mas.exit"), 0)

    def test_health_skips_active_attempt_then_reports_interruption(self):
        self.put("mas.exit", 125)
        with (self.state / "mas.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            self.run_job("health")
            self.assertEqual(self.notices(), 0)
        self.run_job("health")
        self.assertEqual(self.notices(), 1)

    def test_pending_distinct_days_query_failure_and_recovery(self):
        self.env["PENDING"] = "100 Example (1.0 -> 2.0)\n"
        self.run_job("mas")
        self.run_job("mas")
        self.assertEqual(self.number("mas.pending-days"), 1)
        self.env["DAY"] = "20330519"
        self.env["YESTERDAY"] = "20330518"
        self.run_job("mas")
        self.run_job("health")
        self.assertEqual(self.notices(), 1)
        self.env["QUERY_EXIT"] = "1"
        self.run_job("mas", 1)
        self.assertEqual(self.number("mas.pending-days"), 2)
        self.env.update(QUERY_EXIT="0", PENDING="")
        self.run_job("mas")
        self.run_job("health")
        self.assertFalse((self.state / "mas.notified").exists())

    def test_pending_gap_restarts_count(self):
        self.env["PENDING"] = "100 Example (1.0 -> 2.0)\n"
        self.run_job("mas")
        self.env.update(DAY="20330520", YESTERDAY="20330519")
        self.run_job("mas")
        self.assertEqual(self.number("mas.pending-days"), 1)

    def test_missing_and_stale_status_grace(self):
        self.run_job("health")
        self.assertEqual(self.notices(), 0)
        self.env["NOW"] = "2000172801"
        self.run_job("health")
        self.assertEqual(self.notices(), 1)
        self.env["NOW"] = "2000691201"
        self.run_job("health")
        self.assertEqual(self.notices(), 3)

    def test_notification_failure_is_logged(self):
        self.put("mas.exit", 1)
        self.env["NOTICE_EXIT"] = "1"
        self.run_job("health")
        self.assertFalse((self.state / "mas.notified").exists())
        self.assertIn("notification delivery failed", (self.home / "Library/Logs/app-updates/health.log").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)
