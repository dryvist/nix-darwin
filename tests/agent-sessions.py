import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


fixture = json.loads(Path(sys.argv[1]).read_text())
service = fixture["service"]
assert service["KeepAlive"] and service["RunAtLoad"]
assert service["ProcessType"] == "Background" and service["LowPriorityIO"]
assert service["SoftResourceLimits"] == service["HardResourceLimits"]


def wait_for_supervisor(process, client):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        assert process.poll() is None, "launcher exited before supervising its session"
        supervisor = subprocess.run(
            client + ["-N", "show-options", "-gqv", "@agent-launcher-pid"],
            capture_output=True, text=True, timeout=15
        )
        if supervisor.returncode == 0 and supervisor.stdout.strip() == str(process.pid):
            return
        time.sleep(0.05)
    raise AssertionError("launcher did not claim supervision of its session")


with tempfile.TemporaryDirectory(prefix="agent-sessions-") as directory:
    arguments = service["ProgramArguments"]
    arguments = [
        f"HOME={directory}" if arg.startswith("HOME=") else arg for arg in arguments
    ]
    arguments[-2:] = ["-S", f"{directory}/tmux.sock"]
    client = [fixture["tmux"], *arguments[-2:]]
    probe = Path(directory, "probe.json")
    for attempt in range(3):
        probe.unlink(missing_ok=True)
        with Path(directory, "server.log").open("w+") as log:
            process = subprocess.Popen(
                arguments,
                env={**os.environ, "FORBIDDEN_INHERITED_MARKER": "present"},
                stdout=log,
                stderr=log,
            )
            try:
                deadline = time.monotonic() + 15
                while not probe.exists() and time.monotonic() < deadline:
                    if process.poll() is not None:
                        break
                    time.sleep(0.05)
                log.seek(0)
                assert probe.exists(), log.read()
                observed = json.loads(probe.read_text())
                assert observed["argv"] == ["argument with spaces", "quote'and\"dollar$"]
                assert "FORBIDDEN_INHERITED_MARKER" not in observed["env"]
                assert observed["cwd"] == "/"
                assert process.poll() is None, "launchd waiter exited while the session was alive"
                wait_for_supervisor(process, client)
                subprocess.run(client + ["has-session", "-t", "probe"], check=True, timeout=15)
                if attempt == 1:
                    pane = subprocess.check_output(client + ["display-message", "-p", "-t", "probe", "#{pane_pid}"], timeout=15)
                    process.kill()
                    assert process.wait(timeout=15) == -9
                    subprocess.run(client + ["has-session", "-t", "probe"], check=True, timeout=15)
                    process = subprocess.Popen(arguments, stdout=log, stderr=log)
                    wait_for_supervisor(process, client)
                    assert subprocess.check_output(client + ["display-message", "-p", "-t", "probe", "#{pane_pid}"], timeout=15) == pane
                    process.terminate()
                else:
                    subprocess.run(client + ["send-keys", "-t", "probe", "Enter"], check=True, timeout=15)
                exit_code = process.wait(timeout=15)
                log.seek(0)
                assert exit_code == 0, f"launcher failed after stop: {exit_code}: {log.read()}"
                stopped = subprocess.run(client + ["-N", "has-session", "-t", "probe"], capture_output=True, timeout=15)
                assert stopped.returncode != 0, "server survived launcher termination"
                print(f"PASS attempt {attempt + 1}: foreground waiter, argv, clean environment, "
                      + ("SIGKILL adoption and termination cleanup" if attempt == 1 else "child exit"))
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=15)
    print("PASS same isolated socket restarts after child exit and launcher termination")
