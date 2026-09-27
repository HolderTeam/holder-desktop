import os
from pathlib import Path
import subprocess
import tempfile
import unittest


LAUNCHER = Path(__file__).resolve().parents[1] / "packaging/linux/holder"


class HolderLauncherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="holder-launcher-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.root / "state").write_text("stopped")
        self.fake("holderctl", '''
test "$1" = health || exit 2
test "$(cat "$HOLDER_TEST_ROOT/state")" = healthy
''')
        self.fake("systemctl", '''
if [ "$2" = start ]; then
    printf 'start\n' >> "$HOLDER_TEST_ROOT/actions"
    case "$HOLDER_START_MODE" in
        succeeds) printf 'healthy' > "$HOLDER_TEST_ROOT/state" ;;
        race) printf 'healthy' > "$HOLDER_TEST_ROOT/state"; exit 1 ;;
        fails) printf 'service unavailable\n' >&2; exit 1 ;;
    esac
    exit 0
fi
if [ "$2" = is-failed ]; then
    test "$HOLDER_START_MODE" = failed-unit
    exit $?
fi
exit 2
''')
        self.fake("holder-desktop", '''
printf '%s\n' "$@" > "$HOLDER_TEST_ROOT/desktop-args"
''')
        self.fake("zenity", '''
printf '%s\n' "$@" > "$HOLDER_TEST_ROOT/dialog-args"
''')

    def fake(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/sh\n" + body)
        path.chmod(0o755)

    def launch(self, mode="succeeds"):
        env = os.environ.copy()
        env.update({
            "PATH": f"{self.bin}:{env['PATH']}",
            "HOLDER_TEST_ROOT": str(self.root),
            "HOLDER_START_MODE": mode,
            "DISPLAY": ":99",
        })
        return subprocess.run(
            [str(LAUNCHER), "--width", "800"], env=env,
            capture_output=True, text=True, timeout=5,
        )

    def test_reuses_healthy_daemon_and_passes_arguments(self):
        (self.root / "state").write_text("healthy")
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "desktop-args").read_text(), "--width\n800\n")
        self.assertFalse((self.root / "actions").exists())

    def test_starts_service_and_waits_for_health(self):
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "actions").read_text(), "start\n")
        self.assertEqual((self.root / "desktop-args").read_text(), "--width\n800\n")

    def test_reports_start_failure_without_opening_desktop(self):
        result = self.launch("fails")
        self.assertEqual(result.returncode, 1)
        self.assertIn("service unavailable", result.stderr)
        self.assertIn("holder-daemon.service", (self.root / "dialog-args").read_text())
        self.assertFalse((self.root / "desktop-args").exists())

    def test_reuses_daemon_that_becomes_ready_during_service_start(self):
        result = self.launch("race")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "desktop-args").read_text(), "--width\n800\n")

    def test_reports_failed_unit_without_opening_desktop(self):
        result = self.launch("failed-unit")
        self.assertEqual(result.returncode, 1)
        self.assertIn("did not become healthy", result.stderr)
        self.assertFalse((self.root / "desktop-args").exists())


if __name__ == "__main__":
    unittest.main()
